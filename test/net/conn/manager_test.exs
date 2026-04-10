defmodule Net.Conn.ManagerTest do
  use ExUnit.Case, async: false

  alias Net.Conn
  alias Net.Conn.Manager

  test "add/get/has connection lifecycle" do
    conn = Conn.new("127.0.0.1:1234", true, "service")
    Manager.add_connection(conn)

    assert Manager.has_connection?(conn.addr)
    assert %Conn{addr: "127.0.0.1:1234"} = Manager.get_connection(conn.addr)
  end
end
