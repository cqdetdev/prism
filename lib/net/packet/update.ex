defmodule Net.Packet.Update do
    use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

    field :name , 1, type: :string
    field :value, 2, type: :string
end
