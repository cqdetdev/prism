defmodule Net.Manager do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{connections: %{}}, name: __MODULE__)
  end

  def init(opts) do
    {:ok, opts}
  end

  def connections do
    GenServer.call(__MODULE__, :connections)
  end

  def add_connection(conn) do
    GenServer.call(__MODULE__, {:add_connection, conn})
  end

  def remove_connection(conn) do
    GenServer.call(__MODULE__, {:remove_connection, conn})
  end

  def handle_call(:connections, _from, state) do
    {:reply, state.connections, state}
  end

  def handle_call({:add_connection, conn}, _from, state) do
    {:reply, state.connections, Map.put(state.connections, conn.ip, conn)}
  end

  def handle_call({:remove_connection, conn}, _from, state) do
    {:reply, state.connections, Map.delete(state.connections, conn.ip)}
  end
end
