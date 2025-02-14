defmodule Net.Packet.AuthReponse do
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field :status, 1, type: :int32
  field :message, 2, type: :string
end
