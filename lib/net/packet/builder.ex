defmodule Net.Packet.Builder do
  alias Net.Packet.{Response, Data}

  def auth_response(message, status) do
    auth_response = %Response{message: message, status: status}

    data_packet(3, :auth_response, auth_response)
  end

  defp data_packet(type, id, payload) do
    data_packet = %Data{
      type: type,
      payload: {id, payload}
    }

    Data.encode(data_packet)
  end
end
