defmodule Net.Server do
  use GenServer

  def start_link(port) do
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end

  def init(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
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
          Net.Manager.add_connection(Net.Conn.new(ip_string, port, false, "test"))
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
        IO.puts("Received from #{remote_addr}: #{data}")
        read_packets(client, remote_addr)

      {:error, :closed} ->
        IO.puts("Connection closed by #{remote_addr}")
        Net.Manager.remove_connection(remote_addr)

      {:error, reason} ->
        IO.puts("Error receiving data: #{inspect(reason)}")
    end
  end
end
