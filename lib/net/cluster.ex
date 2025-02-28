defmodule Net.Cluster do
  require Logger

  @retry_interval 500

  def connect(:na) do
    attempt_connection(:eu@localhost)
    attempt_connection(:as@localhost)
  end
  def connect(:eu) do
    attempt_connection(:na@localhost)
    attempt_connection(:as@localhost)
  end
  def connect(:as) do
    attempt_connection(:na@localhost)
    attempt_connection(:eu@localhost)
  end
  def connect(region) do
    Logger.error("Unknown region: #{inspect(region)}")
    :error
  end

  defp attempt_connection(node) do
    case Node.connect(node) do
      true ->
        Logger.info("Connected to distributed node: #{node}")
        :ok

      false ->
        Logger.error("Failed to connect to #{node}. Retrying in #{@retry_interval} ms...")
        Process.sleep(@retry_interval)
        attempt_connection(node)
    end
  end

  def broadcast_update(data) do
    Node.list()
    |> Enum.each(fn node ->
      Logger.debug("Sending update to #{node}")
      Node.spawn_link(node, fn ->
        region = node_to_region(node)
        GenServer.call({:global, region}, {:update, data})
      end)
    end)
  end

  defp node_to_region(:eu@localhost), do: :eu
  defp node_to_region(:na@localhost), do: :na
  defp node_to_region(:as@localhost), do: :as
  defp node_to_region(node) do
    Logger.warning("Unrecognized node: #{node}")
    nil
  end
end
