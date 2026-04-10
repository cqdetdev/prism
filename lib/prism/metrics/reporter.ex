defmodule Prism.Metrics.Reporter do
  use GenServer

  require Logger

  @flush_interval_ms 10_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def snapshot do
    GenServer.call(__MODULE__, :snapshot)
  end

  @impl true
  def init(_opts) do
    events = [
      [:prism, :packet, :ingress],
      [:prism, :packet, :decode_error],
      [:prism, :packet, :processing],
      [:prism, :reliability, :retry],
      [:prism, :reliability, :timeout],
      [:prism, :reliability, :backpressure_drop],
      [:prism, :auth, :result],
      [:prism, :handler, :duration],
      [:prism, :handler, :error],
      [:prism, :handler, :timeout],
      [:prism, :cluster, :broadcast_attempt],
      [:prism, :cluster, :broadcast_success],
      [:prism, :cluster, :broadcast_failure]
    ]

    :ok =
      :telemetry.attach_many(
        "prism-metrics-reporter",
        events,
        &__MODULE__.handle_event/4,
        %{pid: self()}
      )

    Process.send_after(self(), :flush, @flush_interval_ms)
    {:ok, initial_state()}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:flush, state) do
    Logger.info(
      "Metrics snapshot ingress=#{state.packet_ingress} decode_errors=#{state.packet_decode_errors} retries=#{state.retries} timeouts=#{state.timeouts} backpressure=#{state.backpressure_drops} handler_errors=#{state.handler_errors} handler_timeouts=#{state.handler_timeouts} auth=#{inspect(state.auth_results)} cluster=#{inspect(state.cluster)} p95_packet_ms=#{format_ms(percentile(state.packet_durations, 0.95))} p95_handler_ms=#{format_ms(percentile(state.handler_durations, 0.95))}"
    )

    Process.send_after(self(), :flush, @flush_interval_ms)
    {:noreply, %{state | packet_durations: [], handler_durations: []}}
  end

  @impl true
  def handle_info({:event, event, measurements, metadata}, state) do
    case {event, measurements, metadata} do
      {[:prism, :packet, :ingress], _m, _md} ->
        {:noreply, %{state | packet_ingress: state.packet_ingress + 1}}

      {[:prism, :packet, :decode_error], _m, _md} ->
        {:noreply, %{state | packet_decode_errors: state.packet_decode_errors + 1}}

      {[:prism, :packet, :processing], %{duration: duration}, _md} ->
        {:noreply, %{state | packet_durations: [duration | state.packet_durations]}}

      {[:prism, :handler, :duration], %{duration: duration}, _md} ->
        {:noreply, %{state | handler_durations: [duration | state.handler_durations]}}

      {[:prism, :reliability, :retry], _m, _md} ->
        {:noreply, %{state | retries: state.retries + 1}}

      {[:prism, :reliability, :timeout], _m, _md} ->
        {:noreply, %{state | timeouts: state.timeouts + 1}}

      {[:prism, :reliability, :backpressure_drop], _m, _md} ->
        {:noreply, %{state | backpressure_drops: state.backpressure_drops + 1}}

      {[:prism, :auth, :result], _m, %{status: status}} ->
        auth_results = Map.update(state.auth_results, status, 1, &(&1 + 1))
        {:noreply, %{state | auth_results: auth_results}}

      {[:prism, :cluster, :broadcast_attempt], _m, _md} ->
        cluster = Map.update(state.cluster, :attempt, 1, &(&1 + 1))
        {:noreply, %{state | cluster: cluster}}

      {[:prism, :cluster, :broadcast_success], _m, _md} ->
        cluster = Map.update(state.cluster, :success, 1, &(&1 + 1))
        {:noreply, %{state | cluster: cluster}}

      {[:prism, :cluster, :broadcast_failure], _m, _md} ->
        cluster = Map.update(state.cluster, :failure, 1, &(&1 + 1))
        {:noreply, %{state | cluster: cluster}}

      {[:prism, :handler, :error], _m, _md} ->
        {:noreply, %{state | handler_errors: state.handler_errors + 1}}

      {[:prism, :handler, :timeout], _m, _md} ->
        {:noreply, %{state | handler_timeouts: state.handler_timeouts + 1}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    :telemetry.detach("prism-metrics-reporter")
    :ok
  end

  def handle_event(event, measurements, metadata, %{pid: pid}) do
    send(pid, {:event, event, measurements, metadata})
  end

  defp initial_state do
    %{
      packet_ingress: 0,
      packet_decode_errors: 0,
      packet_durations: [],
      handler_durations: [],
      retries: 0,
      timeouts: 0,
      backpressure_drops: 0,
      handler_errors: 0,
      handler_timeouts: 0,
      auth_results: %{},
      cluster: %{attempt: 0, success: 0, failure: 0}
    }
  end

  defp percentile([], _), do: 0

  defp percentile(values, p) do
    sorted = Enum.sort(values)
    idx = max(0, min(length(sorted) - 1, round((length(sorted) - 1) * p)))
    Enum.at(sorted, idx)
  end

  defp format_ms(duration_native) when is_integer(duration_native) do
    (System.convert_time_unit(duration_native, :native, :microsecond) / 1000)
    |> Float.round(2)
  end

  defp format_ms(duration_native) when is_float(duration_native) do
    duration_native
    |> trunc()
    |> format_ms()
  end
end
