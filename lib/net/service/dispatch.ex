defmodule Net.Service.Dispatch do
  use GenServer

  @table :prism_dispatch_handlers

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register_handler(route, handler) when is_tuple(route) do
    register_handler(:*, route, handler, [])
  end

  def register_handler(route, handler, opts) when is_tuple(route) and is_list(opts) do
    register_handler(:*, route, handler, opts)
  end

  def register_handler(service_name, route, handler, opts \\ []) do
    GenServer.call(__MODULE__, {:register_handler, service_name, route, handler, opts})
  end

  def get_handler(service_name, routes) when is_list(routes) do
    Enum.find_value(routes, fn route ->
      lookup(service_name, route) || lookup(:*, route)
    end)
  end

  @impl true
  def init(state) do
    _ =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, state}
  end

  @impl true
  def handle_call({:register_handler, service_name, route, handler, opts}, _from, state) do
    spec = %{
      route: route,
      handler: normalize_handler(handler),
      async?: Keyword.get(opts, :async, true),
      timeout:
        Keyword.get(opts, :timeout, Application.get_env(:prism, :handler_timeout_ms, 5_000))
    }

    key = {service_name, route}
    true = :ets.insert(@table, {key, spec})
    new_state = Map.put(state, key, spec)
    {:reply, :ok, new_state}
  end

  def invoke(%{handler: handler}, context) do
    case handler do
      {:mfa, module, function} ->
        apply(module, function, [context])

      fun when is_function(fun, 1) ->
        fun.(context)

      fun when is_function(fun, 2) ->
        fun.(context.conn, {context.payload_kind, context.payload})
    end
  end

  defp lookup(service_name, route) do
    key = {service_name, route}

    case :ets.lookup(@table, key) do
      [{^key, spec}] -> spec
      [] -> nil
    end
  end

  defp normalize_handler({:mfa, module, function})
       when is_atom(module) and is_atom(function),
       do: {:mfa, module, function}

  defp normalize_handler({module, function}) when is_atom(module) and is_atom(function),
    do: {:mfa, module, function}

  defp normalize_handler(handler) when is_function(handler, 1), do: handler
  defp normalize_handler(handler) when is_function(handler, 2), do: handler
end
