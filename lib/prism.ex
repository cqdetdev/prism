defmodule Prism do
  use Application

  def start(_type, _args) do
    region = detect_region()
    children = [
      Net.Reliability.Manager,
      {Data.Repo, []},
      {Redix, name: :redix},
      {Net.Manager, []},
    ] ++ start_server(region)

    opts = [strategy: :one_for_one, name: Net.Listener.Supervisor]

    Net.Service.Registry.register_service("players", "Players-Token", [])

    Supervisor.start_link(children, opts)
  end

  defp detect_region do
    region_key = System.get_env("REGION") || "unknown"
    Application.get_env(:prism, :regions)
    |> Map.get(region_key, %{address: :unknown, port: nil, peers: []})
  end

  defp start_server(%{address: address, port: port}) when is_integer(port) do
    [{Net.Server, [port: port, region: address]}]
  end

  defp start_server(_), do: []
end
