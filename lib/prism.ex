defmodule Prism do
  use Application

  def start(_type, _args) do
    region = detect_region()
    children = [
      Net.Service.Registry,
      Net.Reliability.Manager,
      Net.Conn.Manager,
      Data.Repo,
      {Redix, name: :redix},
    ] ++ start_server(region)

    opts = [strategy: :one_for_one, name: Net.Listener.Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    register_services()

    {:ok, supervisor}
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

  defp register_services do
    Net.Service.Registry.register_service("default_service", "default_token", [4, 5])
  end
end
