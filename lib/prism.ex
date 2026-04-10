defmodule Prism do
  require Logger
  use Application

  alias Net.Conn
  alias Net.Packet.Builder
  alias Prism.Service

  def start(_type, _args) do
    region = detect_region()
    Application.put_env(:prism, :current_region_address, region.address)

    children =
      []
      |> maybe_child(Application.get_env(:prism, :start_cluster, true), Net.Cluster)
      |> maybe_child(Application.get_env(:prism, :metrics_reporter, true), Prism.Metrics.Reporter)
      |> Kernel.++([
        Net.Service.AuthLimiter,
        Net.Service.Registry,
        Net.Reliability.Manager,
        Net.Service.Dispatch,
        Net.Conn.Manager,
        {Task.Supervisor, name: Prism.HandlerSupervisor}
      ])
      |> maybe_child(Application.get_env(:prism, :start_database, true), Data.Repo)
      |> maybe_child(
        Application.get_env(:prism, :start_redix, true),
        {Redix, name: :redix}
      )
      |> Kernel.++(start_server(region))

    opts = [strategy: :one_for_one, name: Net.Listener.Supervisor]
    {:ok, supervisor} = Supervisor.start_link(children, opts)

    register_configured_services()

    {:ok, supervisor}
  end

  def register_service(module) when is_atom(module) do
    module
    |> Service.spec()
    |> register_service_spec()
  end

  def register_service(name, token, opts \\ []) when is_binary(name) and is_binary(token) do
    routes = Keyword.fetch!(opts, :routes)

    spec = %{
      name: name,
      token: token,
      routes: routes,
      packet_ids:
        routes |> Enum.map(&Service.route_packet_id(&1.route)) |> Enum.uniq() |> Enum.sort(),
      options: Keyword.drop(opts, [:routes])
    }

    register_service_spec(spec)
  end

  def register_handler(service_name, route, handler, opts \\ []) do
    Net.Service.Dispatch.register_handler(service_name, route, handler, opts)
  end

  def reply(%Conn{} = conn, message) when is_binary(message) do
    Net.Server.send_to_conn(conn, message)
  end

  def reply(%Prism.Handler.Context{conn: conn}, message) when is_binary(message) do
    reply(conn, message)
  end

  def json_reply(target, payload, opts \\ [])

  def json_reply(%Conn{} = conn, payload, opts) do
    conn
    |> reply(Builder.json_response(payload, opts))
  end

  def json_reply(%Prism.Handler.Context{conn: conn}, payload, opts) do
    json_reply(conn, payload, opts)
  end

  def broadcast_update(data) do
    Net.Cluster.broadcast_update(data)
  end

  def current_region do
    Application.get_env(:prism, :current_region_address)
  end

  def health do
    Prism.Health.snapshot()
  end

  defp detect_region do
    region_key = System.get_env("REGION") || "unknown"

    Application.get_env(:prism, :regions)
    |> Map.get(region_key, %{address: :unknown, port: nil, peers: []})
  end

  defp start_server(%{address: address, port: port}) when is_integer(port) do
    if Application.get_env(:prism, :start_udp, true) do
      [{Net.Server, [port: port, region: address]}]
    else
      []
    end
  end

  defp start_server(_), do: []

  defp maybe_child(children, true, child), do: children ++ [child]
  defp maybe_child(children, false, _child), do: children

  defp register_configured_services do
    Application.get_env(:prism, :services, [Prism.Service.Default])
    |> Enum.each(&register_service/1)
  end

  defp register_service_spec(%{
         name: name,
         token: token,
         packet_ids: packet_ids,
         routes: routes,
         options: options
       }) do
    with :ok <- Net.Service.Registry.register_service(name, token, packet_ids, options) do
      Enum.each(routes, fn route_spec ->
        Net.Service.Dispatch.register_handler(name, route_spec.route, route_spec.handler,
          async: route_spec.async?,
          timeout: route_spec.timeout
        )
      end)

      :ok
    else
      {:error, :already_registered} = error ->
        Logger.warning("Service '#{name}' already registered, skipping duplicate registration")
        error
    end
  end
end
