defmodule Net.Service.AuthLimiterTest do
  use ExUnit.Case, async: false

  alias Net.Service.AuthLimiter

  test "rate limits repeated failed login attempts" do
    service = "svc_#{System.unique_integer([:positive])}"
    addr = "127.0.0.1:#{System.unique_integer([:positive])}"
    opts = [login_rate_limit: [max_attempts: 2, window_ms: 60_000]]

    assert :ok = AuthLimiter.allow_login?(service, addr, opts)
    AuthLimiter.record_failure(service, addr)

    assert :ok = AuthLimiter.allow_login?(service, addr, opts)
    AuthLimiter.record_failure(service, addr)

    assert {:error, :rate_limited} = AuthLimiter.allow_login?(service, addr, opts)

    AuthLimiter.clear(service, addr)
    assert :ok = AuthLimiter.allow_login?(service, addr, opts)
  end
end
