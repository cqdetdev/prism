defmodule Prism.HealthTest do
  use ExUnit.Case, async: false

  test "reports disabled components in test mode" do
    snapshot = Prism.health()

    assert snapshot.status == :ok
    assert snapshot.udp == :disabled
    assert snapshot.database == :disabled
    assert snapshot.redis == :disabled
    assert snapshot.cluster.enabled == false
    assert snapshot.metrics == {:error, :not_running}
    assert "default_service" in snapshot.services
  end
end
