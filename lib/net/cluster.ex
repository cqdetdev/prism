defmodule Net.Cluster do
  use GenServer
  require Logger

  @retry_interval 500
  @max_retries 5

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{peers: [], attempts: %{}}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  def connect(%{address: _address, peers: peers}) when is_list(peers) do
    GenServer.cast(__MODULE__, {:connect, peers})
  end

  def connect(region_config) do
    Logger.error("Invalid region configuration: #{inspect(region_config)}")
    :error
  end

  @impl true
  def handle_cast({:connect, peers}, state) do
    attempts = Enum.into(peers, %{}, fn peer -> {peer, 0} end)
    Process.send_after(self(), :attempt_connections, 0)
    {:noreply, %{state | peers: peers, attempts: attempts}}
  end

  @impl true
  def handle_info(:attempt_connections, state) do
    updated_attempts =
      Enum.reduce(state.peers, state.attempts, fn node, attempts ->
        if Node.connect(node) do
          Logger.info("Connected to distributed node: #{node}")
          Map.delete(attempts, node)
        else
          retries = Map.get(attempts, node, 0)

          if retries < @max_retries do
            Logger.error("Failed to connect to #{node}. Retrying in #{@retry_interval} ms...")
            Map.put(attempts, node, retries + 1)
          else
            Logger.error("Max retries exceeded for peer node #{node}")
            attempts
          end
        end
      end)

    if map_size(updated_attempts) > 0 do
      Process.send_after(self(), :attempt_connections, @retry_interval)
    end

    {:noreply, %{state | attempts: updated_attempts}}
  end

  def broadcast_update(data) do
    Node.list()
    |> Enum.each(fn node ->
      :telemetry.execute([:prism, :cluster, :broadcast_attempt], %{count: 1}, %{node: node})

      result =
        try do
          GenServer.call({:global, node}, {:update, data}, 1_000)
        catch
          :exit, reason -> {:error, reason}
        end

      case result do
        :ok ->
          :telemetry.execute([:prism, :cluster, :broadcast_success], %{count: 1}, %{node: node})

        {:error, reason} ->
          Logger.warning("Cluster broadcast to #{inspect(node)} failed: #{inspect(reason)}")
          :telemetry.execute([:prism, :cluster, :broadcast_failure], %{count: 1}, %{node: node})
      end
    end)
  end
end
