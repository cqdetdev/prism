defmodule Net.ServerTest do
  use ExUnit.Case, async: false

  alias Net.Conn

  test "udp socket errors do not crash the server callback" do
    state = %{socket: :fake_socket, port: 6969, region: :"na1@127.0.0.1"}

    assert {:noreply, ^state} =
             Net.Server.handle_info({:udp_error, :fake_socket, :econnreset}, state)
  end

  test "send_to_conn defers replies when already in server process" do
    region = :"test-region@127.0.0.1"
    previous_region = Application.get_env(:prism, :current_region_address)

    Application.put_env(:prism, :current_region_address, region)
    assert :yes == :global.register_name(region, self())

    on_exit(fn ->
      :global.unregister_name(region)

      if previous_region do
        Application.put_env(:prism, :current_region_address, previous_region)
      else
        Application.delete_env(:prism, :current_region_address)
      end
    end)

    assert :ok = Net.Server.send_to_conn(Conn.new("127.0.0.1:9999", true, "svc"), "payload")

    assert_receive {:send_reliable_async, {127, 0, 0, 1}, 9999, "payload"}
  end
end
