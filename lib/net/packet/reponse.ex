defmodule Net.Packet.Response do
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  @ok "OK"
  @invalid_credentials "INVALID_CREDENTIALS"
  @invalid_service "INVALID_SERVICE"
  @login_required "LOGIN_REQUIRED"
  @invalid_packet "INVALID_PACKET"

  def ok, do: @ok
  def invalid_credentials, do: @invalid_credentials
  def invalid_service, do: @invalid_service
  def login_required, do: @login_required
  def invalid_packet, do: @invalid_packet

  @success 2
  @failure 1

  def success, do: @success
  def failure, do: @failure

  field(:status, 1, type: :int32)
  field(:message, 2, type: :string)
end
