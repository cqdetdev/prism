defmodule Net.Reliability.Parser do
  def parse_packet(<<1::8, seq_num::32, checksum::32, data::binary>>) do
    check = <<1::8, seq_num::32, 0, 0, 0, 0, data::binary>>
    if valid_checksum?(check, checksum) do
      {:data, seq_num, data, checksum}
    else
      :error
    end
  end

  def parse_packet(<<2::8, seq_num::32>>) do
    {:ack, seq_num}
  end

  def parse_packet(_) do
    :error
  end

  defp valid_checksum?(data, checksum) do
    :erlang.crc32(data) == checksum
  end
end
