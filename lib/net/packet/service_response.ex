defmodule Net.Packet.ServiceResponse do
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3
  @behaviour Net.Packet.Behavior

  @impl true
  def id, do: 6

  field(:status, 1, type: :int32)
  field(:message, 2, type: :string)
  field(:payload, 3, type: :string)
end
