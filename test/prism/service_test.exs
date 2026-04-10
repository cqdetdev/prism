defmodule Prism.ServiceTest.ExampleService do
  use Prism.Service,
    name: "example_service",
    token: "example_token",
    login_rate_limit: [max_attempts: 3, window_ms: 1_000]

  handle_request(42, :handle_request)
  handle_update("kills", :handle_update)

  def handle_request(_context), do: :ok
  def handle_update(_context), do: :ok
end

defmodule Prism.ServiceTest do
  use ExUnit.Case, async: true

  alias Net.Packet.Builder
  alias Prism.Service

  test "builds a service spec from the DSL module" do
    spec = Service.spec(Prism.ServiceTest.ExampleService)

    assert spec.name == "example_service"
    assert spec.token == "example_token"
    assert spec.packet_ids == [4, 5]
    assert Enum.any?(spec.routes, &(&1.route == {:request, 42}))
    assert Enum.any?(spec.routes, &(&1.route == {:update, "kills"}))
  end

  test "builds json service response packets" do
    packet = Builder.json_response(%{hello: "world"}, status: 7, message: "CUSTOM")
    decoded = Net.Packet.Data.decode(packet)

    assert decoded.type == Net.Packet.ServiceResponse.id()
    assert {:service_response, response} = decoded.payload
    assert response.status == 7
    assert response.message == "CUSTOM"
    assert response.payload == ~s({"hello":"world"})
  end
end
