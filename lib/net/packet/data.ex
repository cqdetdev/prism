defmodule Net.Packet.Data do
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field(:type, 1, type: :int32)
  oneof(:payload, 2)

  field(:login, 2, type: Net.Packet.Login, oneof: 2)
  field(:auth_response, 3, type: Net.Packet.Response, oneof: 2)
  field(:update, 4, type: Net.Packet.Update, oneof: 2)
  field(:request, 5, type: Net.Packet.Request, oneof: 2)
end
