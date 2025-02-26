defmodule Net.Server do
  use GenServer
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3
  alias Net.Packet.{Login, AuthResponse, DataPacket}
  alias Net.{Manager, Cluster, Reliability}

  require Logger

  def start_link(opts) do
    port = opts[:port]
    region = opts[:region]
    Cluster.connect(region)
    GenServer.start_link(__MODULE__, %{port: port, region: region}, name: {:global, region})
  end

  @impl true
  def init(%{port: port, region: region}) do
    Logger.debug("UDP Server listening on port #{port} in region #{region}")
    {:ok, socket} = :gen_udp.open(port, [:binary, active: true])
    {:ok, %{socket: socket, region: region}}
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, state) do
    buffer = :erlang.iolist_to_binary(data)
    addr = format_address(ip, port)

    case Reliability.Parser.parse_packet(buffer) do
      {:ack, seq_num} ->
        Logger.debug("Received reliable ACK (from: #{addr})")
        Reliability.Manager.acknowledge_packet(addr, seq_num)
        {:noreply, state}

      {:data, seq_num, payload, _checksum} ->
        Logger.debug("Received reliable data packet (from: #{addr})")
        send_ack(state.socket, ip, port, seq_num)

        unless Reliability.Manager.already_processed?(addr, seq_num) do
          Reliability.Manager.mark_as_processed(addr, seq_num)

          if Map.has_key?(Net.Manager.connections(), addr) do
            handle_packet_sequence(state.socket, ip, port, payload)
          else
            Manager.add_connection(Net.Conn.new(addr, false, "test"))
            handle_login_sequence(state.socket, ip, port, payload)
          end
        end

        {:noreply, state}

      :error ->
        Logger.warning("Received unreliable packet (from: #{addr})")
        if Map.has_key?(Net.Manager.connections(), addr) do
          handle_packet_sequence(state.socket, ip, port, buffer)
        else
          Manager.add_connection(Net.Conn.new(addr, false, "test"))
          handle_login_sequence(state.socket, ip, port, buffer)
        end

        {:noreply, state}
    end
  end

  # Handle retry timer
  def handle_info(:check_retransmissions, state) do
    Reliability.Manager.process_retransmissions(state.socket)
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
    {seq_num, packet} = Reliability.Packet.build_packet(message)

    # Register for potential retransmission
    Reliability.Manager.register_packet(addr, seq_num, message, {ip, port})

    # Send the packet
    :ok = :gen_udp.send(state.socket, ip, port, packet)

    {:reply, {:ok, seq_num}, state}
  end

  defp handle_login_sequence(socket, ip, port, data) do
    case Login.decode(data) do
      packet ->
        addr = format_address(ip, port)
        Net.Manager.add_connection(Net.Conn.new(addr, true, packet.service))
        Logger.debug("Login packet received from #{addr}")
        # do_auth()
        auth_response = %AuthResponse{status: 0, message: "OK"}
        data_pk = %DataPacket{
          type: 2,
          payload: {:auth_response, auth_response}
        }
        encoded_data = DataPacket.encode(data_pk)
        send_reliable(socket, ip, port, encoded_data)
    end
  end

  defp handle_packet_sequence(_socket, ip, port, data) do
    case DataPacket.decode(data) do
      %DataPacket{type: 4, payload: {:update, pk}} ->
        Logger.debug("Update packet received from #{format_address(ip, port)}")
        Cluster.broadcast_update %{
          from: Node.self(),
          data: pk,
        }
      unknown -> IO.inspect(unknown)
    end
  end

  defp send_ack(socket, ip, port, seq_num) do
    ack_packet = Reliability.Packet.build_ack_packet(seq_num)
    :gen_udp.send(socket, ip, port, ack_packet)
  end

  defp send_reliable(socket, ip, port, message) do
    {seq_num, packet} = Net.Reliability.Packet.build_packet(message)

    Net.Reliability.Manager.register_packet(format_address(ip, port), seq_num, message, {ip, port})

    <<131, 109, _length::32, b::binary>> = :erlang.term_to_binary(packet)

    :gen_udp.send(socket, ip, port, b)

    {:ok, seq_num}
  end

  defp format_address(ip, port), do: "#{:inet.ntoa(ip) |> List.to_string()}:#{port}"
end
