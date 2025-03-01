defmodule Net.Server do
  use GenServer
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  alias Net.Packet.{Builder, Login, DataPacket}
  alias Net.{Cluster, Reliability.Packet, Reliability.Parser}
  alias Net.Conn
  alias Net.Reliability.Manager, as: ReliabilityManager
  alias Net.Conn.Manager, as: ConnManager
  alias Net.Service.Registry

  require Logger

  def start_link(opts) do
    port = opts[:port]
    region = opts[:region]
    Cluster.connect(%{address: region, peers: Application.get_env(:prism, :regions)
      |> Enum.find(fn {_key, cfg} -> cfg.address == region end)
      |> elem(1) |> Map.get(:peers, [])})
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
      {:ack, seq_num} ->
        Logger.debug("Received reliable ACK from #{addr}")
        ReliabilityManager.acknowledge_packet(addr, seq_num)
        {:noreply, state}

      {:data, seq_num, payload, _checksum} ->
        Logger.debug("Received reliable data packet from #{addr}")
        send_ack(state.socket, ip, port, seq_num)

        unless ReliabilityManager.already_processed?(addr, seq_num) do
          ReliabilityManager.mark_as_processed(addr, seq_num)
          if Map.has_key?(ConnManager.connections(), addr) do
            handle_packet_sequence(state.socket, ip, port, payload)
          else
            handle_login_sequence(state.socket, ip, port, payload)
          end
        end

        {:noreply, state}

      :error ->
        Logger.warning("Received unreliable packet from #{addr}")
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
    IO.inspect(data)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:send_reliable, ip, port, message}, _from, state) do
    addr = format_address(ip, port)
    {seq_num, packet} = Packet.build_packet(message)
    ReliabilityManager.register_packet(addr, seq_num, message, {ip, port})
    :ok = :gen_udp.send(state.socket, ip, port, packet)
    {:reply, {:ok, seq_num}, state}
  end

  defp handle_login_sequence(socket, ip, port, data) do
    addr = format_address(ip, port)

    try do
      packet = Login.decode(data)
      IO.inspect packet
      case Registry.verify_service(packet.service, packet.token) do
        :ok ->
          Logger.debug("Valid login packet received from #{addr} (service: #{packet.service})")
          ConnManager.add_connection(Conn.new(addr, true, packet.service))
          encoded = Builder.auth_response("OK", 2)
          send_reliable(socket, ip, port, encoded)

        {:error, :invalid_credentials} ->
          Logger.debug("Invalid login packet received from #{addr} (service: #{packet.service})")
          encoded = Builder.auth_response("INVALID_CREDENTIALS", 1)
          send_reliable(socket, ip, port, encoded)
        {:error, :invalid_service} ->
          Logger.debug("Invalid login packet received from #{addr} (service: #{packet.service})")
          encoded = Builder.auth_response("INVALID_SERVICE", 1)
          send_reliable(socket, ip, port, encoded)
      end
    rescue
      _ ->
        Logger.debug("Invalid login packet from #{addr}")
    end
  end

  defp handle_packet_sequence(_socket, ip, port, data) do
    case DataPacket.decode(data) do
      %DataPacket{type: type, payload: payload} ->
        addr = format_address(ip, port)
        conn = ConnManager.get_connection(addr)
        if Registry.is_packet_allowed?(conn.service, type) do
          Logger.debug("Packet successfully received from #{addr} with type #{type} and payload #{inspect(payload)}")
          case {type, payload} do
            {4, {:update, pk}} ->
              Logger.debug("Update packet received from #{format_address(ip, port)}")
              Cluster.broadcast_update(%{from: Node.self(), data: pk})
            _ ->
              Logger.debug("Unknown packet type #{type} with payload #{inspect(payload)}")
          end
        else
          service = Registry.get_service(conn.service)
          if service == nil do
            Logger.debug("Packet received from #{addr} with type #{type} from invalid service (#{conn.service})")
          else
            Logger.debug("Packet received from #{addr} with type #{type} is not valid for the service (#{conn.service}) [#{inspect service.valid_packets}].")
          end
        end

      unknown ->
        IO.inspect(unknown)
    end
  end

  defp send_ack(socket, ip, port, seq_num) do
    ack_packet = Packet.build_ack_packet(seq_num)
    :gen_udp.send(socket, ip, port, ack_packet)
  end

  defp send_reliable(socket, ip, port, message) do
    {seq_num, packet} = Packet.build_packet(message)
    addr = format_address(ip, port)

    ReliabilityManager.register_packet(addr, seq_num, message, {ip, port})

    <<131, 109, _length::32, bin::binary>> = :erlang.term_to_binary(packet)
    :gen_udp.send(socket, ip, port, bin)
    {:ok, seq_num}
  end

  defp schedule_retransmissions do
    Process.send_after(__MODULE__, :check_retransmissions, 500)
  end

  defp format_address(ip, port) do
    ip_string = ip |> :inet.ntoa() |> to_string()
    "#{ip_string}:#{port}"
  end
end
