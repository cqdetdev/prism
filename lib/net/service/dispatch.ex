defmodule Net.Service.Dispatch do
  use GenServer
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register_handler(packet_type, handler_fun) when is_function(handler_fun, 2) do
    GenServer.call(__MODULE__, {:register_handler, packet_type, handler_fun})
  end

  def get_handler(packet_type) do
    GenServer.call(__MODULE__, {:get_handler, packet_type})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:register_handler, packet_type, handler_fun}, _from, state) do
    new_state = Map.put(state, packet_type, handler_fun)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_handler, packet_type}, _from, state) do
    {:reply, Map.get(state, packet_type), state}
  end
end
