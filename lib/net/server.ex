defmodule Net.Server do
  use GenServer
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  alias Net.Packet.Login

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, {:packet, 0}, active: false, reuseaddr: true])
    IO.puts("TCP Server listening on port #{port}")
    Task.start(fn -> accept_connections(socket) end)
    {:ok, %{socket: socket, connections: %{}}}
  end

  defp accept_connections(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    Task.start(fn -> accept(client) end)

    accept_connections(socket)
  end

  defp accept(client) do
    case :inet.peername(client) do
      {:ok, {ip, port}} ->
        ip_string = :inet.ntoa(ip) |> List.to_string()
        remote_addr = "#{ip_string}:#{port}"
        IO.puts("Client connected from #{remote_addr}")

        if Map.has_key?(Net.Manager.connections(), remote_addr) do
          IO.puts("Client already connected")
        else
          Net.Manager.add_connection(Net.Conn.new(remote_addr, false, "test"))
          IO.puts("Client connected")
        end

        read_packets(client, remote_addr)

      {:error, reason} ->
        IO.puts("Failed to get peer info: #{inspect(reason)}")
    end
  end

  defp read_packets(client, remote_addr) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        if !Net.Manager.has_connection?(remote_addr) do
          do_login_sequence(client, remote_addr, data)
        else

        end


      {:error, :closed} ->
        IO.puts("Connection closed by #{remote_addr}")
        # Net.Manager.remove_connection(remote_addr)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end

  defp do_login_sequence(client, remote_addr, data) do
    Login.decode(data)
      |> case do
        packet ->
          IO.puts("Received login packet from #{remote_addr}")
          Net.Manager.add_connection(Net.Conn.new(remote_addr, true, packet.service))
          read_packets(client, remote_addr)
      end
        read_packets(client, remote_addr)
  end

  defp do_packet_sequence(client, remote_addr, data) do
    IO.puts("Received packet from #{remote_addr}")
    read_packets(client, remote_addr)
  end
end
