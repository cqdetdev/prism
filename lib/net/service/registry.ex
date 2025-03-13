defmodule Net.Service.Registry do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, %{}}
  end

  def register_service(name, token, packet_ids) do
    GenServer.call(__MODULE__, {:register, name, token, packet_ids})
  end

  def get_service(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def verify_service(name, token) do
    GenServer.call(__MODULE__, {:verify, name, token})
  end

  def is_packet_allowed?(service_name, packet_id) do
    GenServer.call(__MODULE__, {:is_packet_allowed, service_name, packet_id})
  end

  def all do
    GenServer.call(__MODULE__, :list)
  end

  @impl true
  def handle_call({:register, name, token, packet_ids}, _from, state) do
    if Map.has_key?(state, name) do
      {:reply, {:error, :already_registered}, state}
    else
      Logger.info(
        "Service '#{name}' registered successfully with allowed packets: #{inspect(packet_ids)}"
      )

      new_state = Map.put(state, name, %{token: token, valid_packets: packet_ids})
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:verify, name, token}, _from, state) do
    case Map.get(state, name) do
      nil ->
        {:reply, {:error, :invalid_service}, state}

      %{token: ^token} ->
        {:reply, :ok, state}

      _ ->
        {:reply, {:error, :invalid_credentials}, state}
    end
  end

  @impl true
  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state, name, nil), state}
  end

  def handle_call({:is_packet_allowed, name, packet_id}, _from, state) do
    case Map.get(state, name) do
      %{valid_packets: valid_packets} ->
        if packet_id in valid_packets do
          {:reply, true, state}
        else
          {:reply, false, state}
        end

      _ ->
        {:reply, false, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state) do
    {:reply, Map.keys(state), state}
  end
end
