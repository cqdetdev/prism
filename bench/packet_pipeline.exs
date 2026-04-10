Mix.Task.run("app.start")

alias Net.Packet.{Builder, Data, Request}
alias Net.Reliability.{Packet, Parser}

request_packet =
  Data.encode(%Data{
    type: Request.id(),
    payload: {:request, %Request{type: Request.get_all_users(), payload: ~s({"limit":25})}}
  })

service_response = Builder.json_response(%{ok: true, users: [%{username: "bench"}]})
{_seq, encrypted_request} = Packet.build_packet(request_packet)

Benchee.run(
  %{
    "encode service response" => fn ->
      Builder.json_response(%{ok: true, users: [%{username: "bench"}]})
    end,
    "build reliable request packet" => fn ->
      Packet.build_packet(request_packet)
    end,
    "parse reliable request packet" => fn ->
      Parser.parse_packet(encrypted_request)
    end,
    "build service response packet" => fn ->
      Packet.build_packet(service_response)
    end
  },
  time: 5,
  memory_time: 2
)
