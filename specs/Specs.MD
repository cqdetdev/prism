# Specs

This is just a simple document of what I want the API to look like eventually. This just gives me a diagram on how to build the clientside stuff once I'm done with making a working server.

## Creating an instance

I hope to implement a simple cluster-sharding system with the broker instance. A cluster should represent a specific region that contains shards with multiple instances of each broker node. Each broker node will then have it's own handling for whatever service/packets are incoming. A cluster will register a single head shard which will be the shard that communicates via OTP to other regions (might change this)

```elixir
defmodule Instance do
  use Application

  alias Packet

  def start(_type, _args) do
    cluster = detect_cluster_region()
    shard = detect_shard_region()
    head = is_head?()

    {:ok, manager} = Oomf.ClusterManager.start_link([cluster, shard, head])

    manager
        |> register_service "PlayerHandler"
        |> set_protocol Oomf.Protocol.UDP # or Oomf.Protocol.WS
        |> register_packet_handler(Packet.Login, handle_login/1)
        |> register_packet_handler(Packet.Fetch, handle_fetch/1)
        |> register_packet_handler(Packet.Update, handle_update/1)

    children = [
      {Redix, name: :redix},
      {manager, [region, head]},
    ]

    opts = [strategy: :one_for_one, name: Instance.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp detect_cluster_region do
    case System.get_env("CLUSTER") do
      nil -> "orphan"
      region -> region
    end
  end

  defp detect_shard_region do
    case System.get_env("SHARD") do
      nil -> "orphan-0"
      region -> region
    end
  end

  defp is_head? do
    case System.get_env("HEAD") do
      "true" -> true
      "false" -> false
    end
  end
end

```