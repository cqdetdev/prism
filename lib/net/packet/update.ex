defmodule Net.Packet.Update do
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3
  @behaviour Net.Packet.Behavior

  @impl true
  def id(), do: 4

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
  field(:type, 3, type: :string)
  field(:persist_cache, 4, type: :bool)
end
