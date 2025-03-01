defmodule Net.Packet.Builder do
  alias Net.Packet.{AuthResponse, DataPacket}

  def auth_response(message, status) do
    auth_response = %AuthResponse{message: message, status: status}

    data_packet(3, :auth_response, auth_response)
  end

  defp data_packet(type, id, payload) do
    data_packet = %DataPacket{
      type: type,
      payload: {id, payload}
    }
    DataPacket.encode(data_packet)
  end
end
