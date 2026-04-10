defmodule Net.Reliability.ParserTest do
  use ExUnit.Case, async: true

  alias Net.Reliability.Parser
  alias Net.Reliability.Packet
  alias Net.Security

  test "parses encrypted data packet" do
    payload = "hello-prism"
    {iv, ciphertext, tag} = Security.encrypt(payload)
    encrypted = <<iv::binary, ciphertext::binary, tag::binary>>
    checksum = :erlang.crc32(<<1::8, 42::32, 0::32, payload::binary>>)
    packet = <<1::8, 42::32, checksum::32, encrypted::binary>>

    assert {:data, 42, ^payload, ^checksum} = Parser.parse_packet(packet)
  end

  test "parses ack packet" do
    assert {:ack, 12} = Parser.parse_packet(<<2::8, 12::32>>)
  end

  test "packet builder and parser round-trip" do
    payload = "round-trip"
    {seq, packet} = Packet.build_packet(payload)
    checksum = :erlang.crc32(<<1::8, seq::32, 0::32, payload::binary>>)

    assert {:data, ^seq, ^payload, ^checksum} = Parser.parse_packet(packet)
  end
end
