defmodule Net.Reliability.Parser do
  @iv_length 12
  @tag_length 16

  alias Net.Security

  require Logger

  def parse_packet(<<1::8, seq_num::32, checksum::32, data::binary>>) do
    <<iv::binary-@iv_length, ciphertext::binary-size(byte_size(data) - @iv_length - @tag_length),
      tag::binary-@tag_length>> = data

    case Security.decrypt(iv, ciphertext, tag) do
      {:ok, dec} ->
        check = <<1::8, seq_num::32, 0, 0, 0, 0, dec::binary>>

        if valid_checksum?(check, checksum) do
          {:data, seq_num, dec, checksum}
        else
          {:error, :invalid_checksum, :erlang.crc32(check), checksum}
        end

      {:error, :invalid_key_size, size} ->
        {:error, :invalid_key_size, size}

      {:error, :decryption_failed} ->
        {:error, :decryption_failed}
    end
  end

  def parse_packet(<<2::8, seq_num::32>>) do
    {:ack, seq_num}
  end

  def parse_packet(_) do
    {:error, :invalid_packet_format}
  end

  @spec try_decode(any(), any(), any()) :: :error | {:ok, any()}
  def try_decode(func, data, addr) do
    try do
      {:ok, func.(data)}
    rescue
      _ ->
        Logger.debug("Invalid packet from #{addr}")
        :error
    end
  end

  defp valid_checksum?(data, checksum) do
    :erlang.crc32(data) == checksum
  end
end
