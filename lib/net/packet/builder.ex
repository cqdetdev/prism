defmodule Net.Packet.Builder do
  alias Net.Packet.{Data, Response, ServiceResponse}

  def auth_response(message, status) do
    auth_response = %Response{message: message, status: status}

    data_packet(3, :auth_response, auth_response)
  end

  def service_response(payload, opts \\ []) when is_binary(payload) do
    service_response = %ServiceResponse{
      status: Keyword.get(opts, :status, 0),
      message: Keyword.get(opts, :message, "OK"),
      payload: payload
    }

    data_packet(ServiceResponse.id(), :service_response, service_response)
  end

  def json_response(payload, opts \\ []) do
    payload
    |> Jason.encode!()
    |> service_response(opts)
  end

  defp data_packet(type, id, payload) do
    data_packet = %Data{
      type: type,
      payload: {id, payload}
    }

    Data.encode(data_packet)
  end
end
