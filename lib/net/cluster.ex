defmodule Net.Cluster do
  require Logger
  @retry_interval 500
  @max_retries 5

  def connect(%{address: _address, peers: peers}) when is_list(peers) do
    Enum.each(peers, &attempt_connection/1)
  end

  def connect(region_config) do
    Logger.error("Invalid region configuration: #{inspect(region_config)}")
    :error
  end

  defp attempt_connection(node, retries \\ 0) do
    case Node.connect(node) do
      true ->
        Logger.info("Connected to distributed node: #{node}")
        :ok

      false ->
        if retries < @max_retries do
          Logger.error("Failed to connect to #{node}. Retrying in #{@retry_interval} ms...")
          Process.sleep(@retry_interval)
          attempt_connection(node, retries + 1)
        else
          Logger.error("Max retries exceeded for peer node #{node}")
        end
    end
  end

  def broadcast_update(data) do
    Node.list()
    |> Enum.each(fn node ->
      Logger.debug("Sending update to #{node}")

      Node.spawn_link(node, fn ->
        GenServer.call({:global, node}, {:update, data})
      end)
    end)
  end
end
