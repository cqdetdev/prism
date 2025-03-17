defmodule Net.Packet.Login do
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3
  @behaviour Net.Packet.Behavior

  @impl true
  def id(), do: 2

  field(:service, 1, type: :string)
  field(:token, 2, type: :string)
end
