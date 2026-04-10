defmodule Net.Service.AuthLimiter do
  use GenServer

  @default_window_ms 60_000
  @default_max_attempts 10

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow_login?(service_name, addr, opts \\ []) do
    GenServer.call(__MODULE__, {:allow_login?, service_name, addr, opts})
  end

  def record_failure(service_name, addr) do
    GenServer.cast(__MODULE__, {:record_failure, service_name, addr})
  end

  def clear(service_name, addr) do
    GenServer.cast(__MODULE__, {:clear, service_name, addr})
  end

  @impl true
  def init(_opts) do
    {:ok, %{failures: %{}}}
  end

  @impl true
  def handle_call({:allow_login?, service_name, addr, opts}, _from, state) do
    {window_ms, max_attempts} = limit_config(opts)
    key = {service_name, addr}
    now = System.system_time(:millisecond)

    recent_attempts =
      state.failures
      |> Map.get(key, [])
      |> Enum.filter(&(now - &1 <= window_ms))

    next_state = put_in(state, [:failures, key], recent_attempts)

    if length(recent_attempts) >= max_attempts do
      {:reply, {:error, :rate_limited}, next_state}
    else
      {:reply, :ok, next_state}
    end
  end

  @impl true
  def handle_cast({:record_failure, service_name, addr}, state) do
    key = {service_name, addr}
    now = System.system_time(:millisecond)
    failures = Map.get(state.failures, key, [])
    {:noreply, put_in(state, [:failures, key], [now | failures])}
  end

  @impl true
  def handle_cast({:clear, service_name, addr}, state) do
    {:noreply, update_in(state.failures, &Map.delete(&1, {service_name, addr}))}
  end

  defp limit_config(opts) do
    config =
      Keyword.get(opts, :login_rate_limit, Application.get_env(:prism, :auth_rate_limit, []))

    {Keyword.get(config, :window_ms, @default_window_ms),
     Keyword.get(config, :max_attempts, @default_max_attempts)}
  end
end
