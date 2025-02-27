defmodule Net.Reliability.Manager do
  use GenServer
  require Logger

  @retry_interval 500
  @max_retries 5

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register_packet(addr, seq_num, data, dest) do
    GenServer.cast(__MODULE__, {:register, addr, seq_num, data, dest})
  end

  def acknowledge_packet(addr, seq_num) do
    GenServer.cast(__MODULE__, {:ack, addr, seq_num})
  end

  def process_retransmissions(socket) do
    GenServer.cast(__MODULE__, {:retry, socket})
  end

  def already_processed?(addr, seq_num) do
    GenServer.call(__MODULE__, {:processed?, addr, seq_num})
  end

  def mark_as_processed(addr, seq_num) do
    GenServer.cast(__MODULE__, {:mark_processed, addr, seq_num})
  end

  @impl true
  def init(_) do
    state = %{
      pending_packets: %{},    # %{addr => %{seq_num => {data, dest, sent_time, retries}}}
      processed_packets: %{}   # %{addr => MapSet<seq_num>}
    }

    schedule_retry_check()
    {:ok, state}
  end

  @impl true
  def handle_cast({:register, addr, seq_num, data, dest}, state) do
    now = :os.system_time(:millisecond)

    updated_pending =
      state.pending_packets
      |> Map.update(addr, %{seq_num => {data, dest, now, 0}}, &Map.put(&1, seq_num, {data, dest, now, 0}))

    {:noreply, %{state | pending_packets: updated_pending}}
  end

  @impl true
  def handle_cast({:ack, addr, seq_num}, state) do
    updated_pending =
      state.pending_packets
      |> update_in([addr], fn addr_map ->
        Map.delete(addr_map || %{}, seq_num)
      end)
      |> clean_empty_maps()

    Logger.debug("Packet #{seq_num} acknowledged by #{addr}")
    {:noreply, %{state | pending_packets: updated_pending}}
  end

  @impl true
  def handle_cast({:retry, socket}, state) do
    state = retry_packets(socket, state)
    schedule_retry_check()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:mark_processed, addr, seq_num}, state) do
    updated_processed =
      state.processed_packets
      |> Map.update(addr, MapSet.new([seq_num]), &MapSet.put(&1, seq_num))
      |> trim_processed_packets(addr)

    {:noreply, %{state | processed_packets: updated_processed}}
  end

  @impl true
  def handle_call({:processed?, addr, seq_num}, _from, state) do
    result = Map.get(state.processed_packets, addr, MapSet.new()) |> MapSet.member?(seq_num)
    {:reply, result, state}
  end

  @impl true
  def handle_info(:check_retransmissions, state) do
    state = retry_packets(nil, state)
    schedule_retry_check()
    {:noreply, state}
  end

  defp schedule_retry_check do
    Process.send_after(self(), :check_retransmissions, @retry_interval)
  end

  defp retry_packets(socket, state) do
    now = :os.system_time(:millisecond)

    updated_pending =
      Enum.reduce(state.pending_packets, %{}, fn {addr, addr_map}, acc ->
        updated_addr_map =
          Enum.reduce(addr_map, %{}, fn {seq_num, {data, {ip, port} = dest, sent_time, retries}}, acc_map ->
            if now - sent_time > @retry_interval do
              if retries < @max_retries do
                packet = Net.Reliability.Packet.build_packet_with_seq(data, seq_num)

                if socket do
                  :ok = :gen_udp.send(socket, ip, port, packet)
                end

                Logger.debug("Retrying packet #{seq_num} to #{addr}, attempt #{retries + 1}")
                Map.put(acc_map, seq_num, {data, dest, now, retries + 1})
              else
                Logger.warning("Packet #{seq_num} to #{addr} timed out after #{@max_retries} retries")
                acc_map
              end
            else
              Map.put(acc_map, seq_num, {data, dest, sent_time, retries})
            end
          end)

        if map_size(updated_addr_map) > 0 do
          Map.put(acc, addr, updated_addr_map)
        else
          acc
        end
      end)

    %{state | pending_packets: updated_pending}
  end

  defp clean_empty_maps(pending_packets) do
    pending_packets
    |> Enum.reject(fn {_addr, addr_map} -> map_size(addr_map) == 0 end)
    |> Enum.into(%{})
  end

  defp trim_processed_packets(processed_packets, addr) do
    Map.update(processed_packets, addr, MapSet.new(), fn set ->
      if MapSet.size(set) > 1000 do
        set
        |> Enum.sort()
        |> Enum.take(-1000)
        |> MapSet.new()
      else
        set
      end
    end)
  end
end
