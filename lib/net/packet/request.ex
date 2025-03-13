defmodule Net.Packet.Request do
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  @create_user 1
  @get_all_users 2
  @get_all_staff 3
  @get_ordered_by_kills 4
  @get_ordered_by_deaths 5

  def create_user, do: @create_user
  def get_all_users, do: @get_all_users
  def get_all_staff, do: @get_all_staff
  def get_ordered_by_kills, do: @get_ordered_by_kills
  def get_ordered_by_deaths, do: @get_ordered_by_deaths

  field(:type, 1, type: :int32)
  field(:payload, 2, type: :string)
end
