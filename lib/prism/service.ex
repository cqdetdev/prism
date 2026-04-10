defmodule Prism.Service do
  @moduledoc false

  @type route :: {:packet, integer()} | {:request, integer()} | {:update, String.t()}
  @type handler :: function() | {module(), atom()} | {:mfa, module(), atom()}
  @type route_spec :: %{
          route: route(),
          handler: handler(),
          async?: boolean(),
          timeout: pos_integer()
        }

  @callback service_name() :: String.t()
  @callback service_token() :: String.t()
  @callback routes() :: [route_spec()]
  @callback options() :: keyword()

  @optional_callbacks options: 0

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)
    token = Keyword.fetch!(opts, :token)
    service_opts = Keyword.drop(opts, [:name, :token])

    quote bind_quoted: [name: name, token: token, service_opts: service_opts] do
      @behaviour Prism.Service
      Module.register_attribute(__MODULE__, :prism_routes, accumulate: true)
      @before_compile Prism.Service

      @prism_service_name name
      @prism_service_token token
      @prism_service_options service_opts

      import Prism.Service,
        only: [
          handle_packet: 2,
          handle_packet: 3,
          handle_request: 2,
          handle_request: 3,
          handle_update: 2,
          handle_update: 3
        ]

      def service_name, do: @prism_service_name
      def service_token, do: @prism_service_token
      def options, do: @prism_service_options

      defoverridable options: 0
    end
  end

  defmacro __before_compile__(env) do
    routes =
      env.module
      |> Module.get_attribute(:prism_routes)
      |> Enum.reverse()
      |> Macro.escape()

    quote do
      def routes, do: unquote(routes)
    end
  end

  defmacro handle_packet(packet_type, handler, opts \\ []) do
    quote bind_quoted: [packet_type: packet_type, handler: handler, opts: opts] do
      @prism_routes Prism.Service.build_route({:packet, packet_type}, handler, opts, __MODULE__)
    end
  end

  defmacro handle_request(request_type, handler, opts \\ []) do
    quote bind_quoted: [request_type: request_type, handler: handler, opts: opts] do
      @prism_routes Prism.Service.build_route({:request, request_type}, handler, opts, __MODULE__)
    end
  end

  defmacro handle_update(update_type, handler, opts \\ []) do
    quote bind_quoted: [update_type: update_type, handler: handler, opts: opts] do
      @prism_routes Prism.Service.build_route({:update, update_type}, handler, opts, __MODULE__)
    end
  end

  def build_route(route, handler, opts, module) do
    %{
      route: route,
      handler: normalize_handler(handler, module),
      async?: Keyword.get(opts, :async, true),
      timeout:
        Keyword.get(opts, :timeout, Application.get_env(:prism, :handler_timeout_ms, 5_000))
    }
  end

  def packet(packet_type, handler, opts \\ []),
    do: build_route({:packet, packet_type}, handler, opts, nil)

  def request(request_type, handler, opts \\ []),
    do: build_route({:request, request_type}, handler, opts, nil)

  def update(update_type, handler, opts \\ []),
    do: build_route({:update, update_type}, handler, opts, nil)

  def spec(module) do
    routes = module.routes()

    %{
      name: module.service_name(),
      token: module.service_token(),
      routes: routes,
      packet_ids: routes |> Enum.map(&route_packet_id(&1.route)) |> Enum.uniq() |> Enum.sort(),
      options: service_options(module)
    }
  end

  def route_packet_id({:packet, packet_type}), do: packet_type
  def route_packet_id({:request, _request_type}), do: Net.Packet.Request.id()
  def route_packet_id({:update, _update_type}), do: Net.Packet.Update.id()

  defp normalize_handler({:mfa, module, function}, _caller_module)
       when is_atom(module) and is_atom(function),
       do: {:mfa, module, function}

  defp normalize_handler({module, function}, _caller_module)
       when is_atom(module) and is_atom(function),
       do: {:mfa, module, function}

  defp normalize_handler(handler, caller_module) when is_atom(handler) and is_atom(caller_module),
    do: {:mfa, caller_module, handler}

  defp normalize_handler(handler, _caller_module) when is_function(handler, 1), do: handler
  defp normalize_handler(handler, _caller_module) when is_function(handler, 2), do: handler

  defp service_options(module) do
    if function_exported?(module, :options, 0), do: module.options(), else: []
  end
end
