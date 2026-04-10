defmodule Net.Service.DispatchTest do
  use ExUnit.Case, async: false

  alias Net.Conn
  alias Net.Packet.{Data, Request}
  alias Net.Service.Dispatch
  alias Prism.Handler.Context

  test "prefers service-specific handlers over wildcard routes" do
    request_type = System.unique_integer([:positive])
    route = {:request, request_type}
    service = "svc_#{request_type}"

    assert :ok = Dispatch.register_handler(:*, route, fn _context -> :wildcard end)
    assert :ok = Dispatch.register_handler(service, route, fn _context -> :specific end)

    context =
      Context.new(
        Conn.new("127.0.0.1:9999", true, service),
        %Data{
          type: Request.id(),
          payload: {:request, %Request{type: request_type, payload: "{}"}}
        },
        route
      )

    assert %{route: ^route} = handler = Dispatch.get_handler(service, [route])
    assert :specific = Dispatch.invoke(handler, context)
  end
end
