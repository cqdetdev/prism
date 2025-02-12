defmodule Net.Conn do
  # ip, port, authenticated, service name
  defstruct ip: nil, port: nil, authenticated: false, service: nil

  def new(ip, port, authenticated, service) do
    %Net.Conn{ip: ip, port: port, authenticated: authenticated, service: service}
  end
end
