defmodule Net.Conn do
  # ip, port, authenticated, service name
  defstruct addr: nil, authenticated: false, service: nil

  def new(addr, authenticated, service) do
    %Net.Conn{addr: addr, authenticated: authenticated, service: service}
  end
end
