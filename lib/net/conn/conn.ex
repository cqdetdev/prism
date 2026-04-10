defmodule Net.Conn do
  # ip, port, authenticated, service name
  defstruct addr: nil, authenticated: false, service: nil

  def new(addr, authenticated, service) do
    %Net.Conn{addr: addr, authenticated: authenticated, service: service}
  end

  def destination(%Net.Conn{addr: addr}) when is_binary(addr) do
    [ip_string, port_string] = String.split(addr, ":", parts: 2)
    {:ok, ip} = :inet.parse_address(String.to_charlist(ip_string))
    {ip, String.to_integer(port_string)}
  end
end
