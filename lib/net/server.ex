defmodule Net.Server do
  use GenServer
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  alias Data.Users

  alias Net.Packet.{Builder, Login, Data, Response}
  alias Net.{Cluster, Reliability.Packet, Reliability.Parser}
  alias Net.Conn
  alias Net.Reliability.Manager, as: ReliabilityManager
  alias Net.Conn.Manager, as: ConnManager
  alias Net.Service.Registry
  alias Net.Security

  require Logger

  def start_link(opts) do
    port = opts[:port]
    region = opts[:region]

    Cluster.connect(%{
      address: region,
      peers:
        Application.get_env(:prism, :regions)
        |> Enum.find(fn {_key, cfg} -> cfg.address == region end)
        |> elem(1)
        |> Map.get(:peers, [])
    })

    GenServer.start_link(__MODULE__, %{port: port, region: region}, name: {:global, region})
  end

  @impl true
  def init(%{port: port, region: region} = state) do
    Logger.debug("UDP Server listening on port #{port} in region #{region}")
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
    schedule_retransmissions()

    {:ok, Map.put(state, :socket, socket)}
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, state) do
    addr = format_address(ip, port)
    buffer = :erlang.iolist_to_binary(data)

    case Parser.parse_packet(buffer) do
      {:ack, seq} ->
        Logger.debug("Received reliable ACK from #{addr}")
        ReliabilityManager.acknowledge_packet(addr, seq)
        {:noreply, state}

      {:data, seq, payload, _checksum} ->
        Logger.debug("Received reliable data packet from #{addr}")
        send_ack(state.socket, ip, port, seq)

        unless ReliabilityManager.already_processed?(addr, seq) do
          ReliabilityManager.mark_as_processed(addr, seq)

          if Map.has_key?(ConnManager.connections(), addr) do
            handle_packet_sequence(state.socket, ip, port, payload)
          else
            handle_login_sequence(state.socket, ip, port, payload)
          end
        end

        {:noreply, state}

      {:error, :invalid_key_size, size} ->
        Logger.warning(
          "Received packet with invalid key size (#{size}) from #{addr} (#{inspect(buffer)})"
        )

        {:noreply, state}

      {:error, :decryption_failed} ->
        Logger.warning("Decryption failed for packet from #{addr} (#{inspect(buffer)})")
        {:noreply, state}

      {:error, :invalid_checksum, expected, received} ->
        Logger.warning(
          "Invalid checksum for packet from #{addr} (Exp: #{inspect(expected)} | Recv: #{inspect(received)})"
        )

        {:noreply, state}

      {:error, :invalid_packet_format} ->
        Logger.warning("Invalid packet format from #{addr} (#{inspect(buffer)})")
        {:noreply, state}
    end
  end

  def handle_info(:check_retransmissions, state) do
    ReliabilityManager.process_retransmissions(state.socket)
    schedule_retransmissions()
    {:noreply, state}
  end

  @impl true
  def handle_call({:update, %{from: from, data: data}}, _from, state) do
    Logger.debug("Background Update (from: #{from}):")
    IO.inspect data
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:send_reliable, ip, port, message}, _from, state) do
    addr = format_address(ip, port)
    {seq, packet} = Packet.build_packet(message)
    ReliabilityManager.register_packet(addr, seq, message, {ip, port})
    :ok = :gen_udp.send(state.socket, ip, port, packet)
    {:reply, {:ok, seq}, state}
  end

  defp handle_login_sequence(socket, ip, port, data) do
    addr = format_address(ip, port)

    with {:ok, packet} <- Parser.try_decode(&Login.decode/1, data, addr) do
      case Registry.verify_service(packet.service, packet.token) do
        :ok ->
          Logger.debug("Valid login packet received from #{addr} (service: #{packet.service})")
          ConnManager.add_connection(Conn.new(addr, true, packet.service))
          pk = Builder.auth_response(Response.ok(), Response.success())
          send_reliable(socket, ip, port, pk)

        {:error, :invalid_credentials} ->
          Logger.debug(
            "Invalid login packet (credentials) received from #{addr} (service: #{packet.service})"
          )

          pk = Builder.auth_response(Response.invalid_credentials(), Response.failure())
          send_reliable(socket, ip, port, pk)

        {:error, :invalid_service} ->
          Logger.debug(
            "Invalid login packet (service) received from #{addr} (service: #{packet.service})"
          )

          pk = Builder.auth_response(Response.invalid_service(), Response.failure())
          send_reliable(socket, ip, port, pk)
      end
    else
      _ ->
        with {:ok, _} <- Parser.try_decode(&Data.decode/1, data, addr) do
          Logger.debug("Received data packet from #{addr} before login")
          pk = Builder.auth_response(Response.login_required(), Response.failure())
          send_reliable(socket, ip, port, pk)
        else
          _ ->
            Logger.debug("Invalid packet from #{addr}")
            pk = Builder.auth_response(Response.invalid_packet(), Response.failure())
            send_reliable(socket, ip, port, pk)
        end
    end
  end

  defp handle_packet_sequence(socket, ip, port, data) do
    addr = format_address(ip, port)

    with {:ok, packet} <- Parser.try_decode(&Data.decode/1, data, addr) do
      %Data{type: type, payload: payload} = packet
      conn = ConnManager.get_connection(addr)

      if Registry.is_packet_allowed?(conn.service, type) do
        Logger.debug("Packet received from #{addr} with type #{type}")

        case Net.Service.Dispatch.get_handler(type) do
          nil ->
            Logger.debug("No handler registered for packet type #{type}")
          handler_fun ->
            # The registered closure is responsible for decoding and handling.
            handler_fun.(conn, payload)
        end
      else
        service = Registry.get_service(conn.service)

        if service == nil do
          Logger.debug("Packet received from #{addr} with type #{type} from invalid service (#{conn.service})")
        else
          Logger.debug("Packet received from #{addr} with type #{type} is not valid for the service (#{conn.service}) [#{inspect(service.valid_packets)}].")
        end
      end
    else
      _ -> Logger.debug("Invalid packet from #{addr}")
    end
  end


  defp send_ack(socket, ip, port, seq) do
    ack_packet = Packet.build_ack_packet(seq)
    :gen_udp.send(socket, ip, port, ack_packet)
  end

  defp send_reliable(socket, ip, port, message, encrypt \\ true) do
    {seq, packet} = Packet.build_packet(message)
    addr = format_address(ip, port)

    ReliabilityManager.register_packet(addr, seq, message, {ip, port})

    <<131, 109, _length::32, bin::binary>> = :erlang.term_to_binary(packet)

    send =
      if encrypt do
        {iv, ciphertext, tag} = Security.encrypt(bin)
        <<iv::binary, ciphertext::binary, tag::binary>>
      else
        bin
      end

    :gen_udp.send(socket, ip, port, send)
    {:ok, seq}
  end

  defp schedule_retransmissions do
    Process.send_after(__MODULE__, :check_retransmissions, 500)
  end

  defp format_address(ip, port) do
    ip_string = ip |> :inet.ntoa() |> to_string()
    "#{ip_string}:#{port}"
  end
end
