defmodule Net.Conn.Manager do
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

  def get_connection(addr) do
    GenServer.call(__MODULE__, {:get_connection, addr})
  end

  def has_connection?(addr) do
    GenServer.call(__MODULE__, {:connection?, addr})
  end

  def handle_call(:connections, _from, state) do
    {:reply, state.connections, state}
  end

  def handle_call({:add_connection, conn}, _from, state) do
    new_connections = Map.put(state.connections, conn.addr, conn)
    {:reply, new_connections, %{state | connections: new_connections}}
  end

  def handle_call({:get_connection, addr}, _from, state) do
    {:reply, Map.get(state.connections, addr, nil), state}
  end

  def handle_call({:connection?, addr}, _from, state) do
    {:reply, Map.has_key?(state.connections, addr), state}
  end

  def handle_call({:remove_connection, conn}, _from, state) do
    new_connections = Map.delete(state.connections, conn.addr)
    {:reply, new_connections, %{state | connections: new_connections}}
  end
end
