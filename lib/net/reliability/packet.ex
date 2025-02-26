defmodule Net.Reliability.Packet do
  # Packet format constants
  @data_type 1
  @ack_type 2
  def build_packet(data) do
    # Generate a new sequence number
    seq_num = generate_sequence_number()

    # Build packet with the sequence number
    packet = build_packet_with_seq(data, seq_num)

    {seq_num, packet}
  end

  def build_packet_with_seq(data, seq_num) when is_binary(data) do
    checksum = calculate_checksum(data)

    # Packet format: <TYPE:1><SEQ_NUM:4><CHECKSUM:4><DATA:*>
    <<@data_type::8, seq_num::32, checksum::32, data::binary>>
  end
  def build_ack_packet(seq_num) do
    # Packet format: <TYPE:1><SEQ_NUM:4>
    <<@ack_type::8, seq_num::32>>
  end

  defp generate_sequence_number do
    # Simple implementation using random numbers
    # In production, you might want to use a more sophisticated approach
    :rand.uniform(2_147_483_647)
  end

  defp calculate_checksum(data) do
    :erlang.crc32(data)
  end
end
