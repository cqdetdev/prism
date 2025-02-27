defmodule Net.Cluster do
  require Logger

  def connect(region) do
    node =
      case region do
        :na -> :eu@localhost
        :eu -> :na@localhost
      end

    attempt_connection(node)
  end

  defp attempt_connection(node) do
    case Node.connect(node) do
      true -> IO.puts("Connected to distributed node: #{node}")
      false ->
        IO.puts("Failed to connect to #{node}. Retrying in 5s...")
        Process.sleep(5000)
        attempt_connection(node)
    end
  end

  def broadcast_update(data) do
    Node.list()
    |> Enum.each(fn node ->
      Logger.debug("Sending update to #{node}")

      Node.spawn_link(node, fn ->
        n = node_to_region(node)
        GenServer.call({:global, n}, {:update, data})
      end)
    end)
  end

  defp node_to_region(node) do
    case node do
      :eu@localhost -> :eu
      :na@localhost -> :na
    end
  end
end
