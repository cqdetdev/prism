defmodule Net.Server do
  use GenServer
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  alias Net.Packet.{Login, AuthReponse, Packet}
  alias Net.{Manager, Cluster}

  def start_link(opts) do
    port = opts[:port]
    region = opts[:region]
    Cluster.connect(region)
    GenServer.start_link(__MODULE__, port, name: {:global, region})
  end

  @impl true
  def init(port) do
    IO.puts("UDP Server listening on port #{port}")
    :gen_udp.open(port)
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, socket) do
    buffer = :erlang.iolist_to_binary(data)
    addr = format_address(ip, port)

    if Map.has_key?(Net.Manager.connections(), addr) do
      handle_packet_sequence(socket, ip, port, buffer)
    else
      Manager.add_connection(Net.Conn.new(addr, false, "test"))
      handle_login_sequence(socket, ip, port, buffer)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_call({:update, %{from: from, data: data}}, _from, state) do
    IO.puts("Backstream Update (from: #{from}): #{data}")
    {:reply, :ok, state}
  end

  defp handle_login_sequence(socket, ip, port, data) do
    Login.decode(data)
    |> case do
      packet ->
        addr = format_address(ip, port)
        Net.Manager.add_connection(Net.Conn.new(addr, true, packet.service))
        IO.puts("Login packet received from #{addr}")
        resp = AuthReponse.encode(%AuthReponse{status: 0, message: "OK"})
        send_response(socket, ip, port, resp)
    end
  end

  defp handle_packet_sequence(_, ip, port, data) do
    case Packet.decode(data) do
      %Packet{type: 4, payload: {:update, _}} ->
        IO.puts("Update packet received from #{format_address(ip, port)}")
      unknown -> IO.inspect(unknown)
    end
  end

  defp format_address(ip, port), do: "#{:inet.ntoa(ip) |> List.to_string()}:#{port}"


  defp send_response(socket, ip, port, message) do
    :gen_udp.send(socket, ip, port, message)
  end
end
