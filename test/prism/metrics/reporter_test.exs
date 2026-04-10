defmodule Prism.Metrics.ReporterTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  test "flush handles empty duration buckets" do
    state = %{
      packet_ingress: 8,
      packet_decode_errors: 0,
      packet_durations: [],
      handler_durations: [],
      retries: 1,
      timeouts: 0,
      backpressure_drops: 0,
      handler_errors: 0,
      handler_timeouts: 0,
      auth_results: %{ok: 1},
      cluster: %{attempt: 0, success: 0, failure: 0}
    }

    log =
      capture_log(fn ->
        assert {:noreply, next_state} = Prism.Metrics.Reporter.handle_info(:flush, state)
        assert next_state.packet_durations == []
        assert next_state.handler_durations == []
      end)

    assert log =~ "p95_packet_ms=0.0"
    assert log =~ "p95_handler_ms=0.0"
  end
end
