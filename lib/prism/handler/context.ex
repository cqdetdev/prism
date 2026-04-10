defmodule Prism.Handler.Context do
  @moduledoc false

  alias Net.Conn
  alias Net.Packet.{Data, Request, Update}

  defstruct [
    :conn,
    :service,
    :packet,
    :packet_type,
    :payload_kind,
    :payload,
    :route,
    :received_at
  ]

  def new(
        %Conn{} = conn,
        %Data{type: packet_type, payload: {payload_kind, payload}} = packet,
        route
      ) do
    %__MODULE__{
      conn: conn,
      service: conn.service,
      packet: packet,
      packet_type: packet_type,
      payload_kind: payload_kind,
      payload: payload,
      route: route,
      received_at: System.system_time(:millisecond)
    }
  end

  def reply(%__MODULE__{conn: conn}, message), do: Prism.reply(conn, message)

  def json_reply(%__MODULE__{} = context, payload, opts \\ []) do
    Prism.json_reply(context.conn, payload, opts)
  end

  def broadcast(%__MODULE__{}, data), do: Prism.broadcast_update(data)

  def decode_json(%__MODULE__{payload: %Request{payload: payload}}) do
    Jason.decode(payload)
  end

  def decode_json(%__MODULE__{payload: %Update{value: payload}}) do
    Jason.decode(payload)
  end

  def decode_json(%__MODULE__{}), do: {:error, :unsupported_payload}

  def request(%__MODULE__{payload: %Request{} = request}), do: request
  def request(%__MODULE__{}), do: nil

  def update(%__MODULE__{payload: %Update{} = update}), do: update
  def update(%__MODULE__{}), do: nil
end
