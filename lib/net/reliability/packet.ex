defmodule Net.Reliability.Packet do
  alias Net.Security

  @data_type 1
  @ack_type 2

  def build_packet(data) do
    seq_num = generate_sequence_number()
    packet = build_packet_with_seq(data, seq_num)

    {seq_num, packet}
  end

  # Packet format: <TYPE:1><SEQ_NUM:4><CHECKSUM:4><IV:12><CIPHERTEXT:*><TAG:16>
  def build_packet_with_seq(data, seq_num) when is_binary(data) do
    checksum = calculate_checksum(seq_num, data)
    {iv, ciphertext, tag} = Security.encrypt(data)
    <<@data_type::8, seq_num::32, checksum::32, iv::binary, ciphertext::binary, tag::binary>>
  end

  # Packet format: <TYPE:1><SEQ_NUM:4>
  def build_ack_packet(seq_num) do
    <<@ack_type::8, seq_num::32>>
  end

  defp generate_sequence_number do
    :rand.uniform(2_147_483_647)
  end

  defp calculate_checksum(seq_num, data) do
    :erlang.crc32(<<@data_type::8, seq_num::32, 0::32, data::binary>>)
  end
end
