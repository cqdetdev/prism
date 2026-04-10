defmodule Net.Service.RegistryTest do
  use ExUnit.Case, async: false

  alias Net.Service.Registry

  test "registers and validates service credentials" do
    service = "svc_#{System.unique_integer([:positive])}"
    assert :ok = Registry.register_service(service, "token", [4, 5])
    assert :ok = Registry.verify_service(service, "token")
    assert {:error, :invalid_credentials} = Registry.verify_service(service, "bad")
    assert {:error, :invalid_service} = Registry.verify_service("unknown", "token")
    assert Registry.is_packet_allowed?(service, 4)
    refute Registry.is_packet_allowed?(service, 100)
  end
end
