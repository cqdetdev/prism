defmodule Net.Reliability.Manager do
  use GenServer
  require Logger

  # Configuration
  @retry_interval 500 # ms
  @max_retries 5

  # Client API

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

  # Server callbacks

  @impl true
  def init(_) do
    state = %{
      pending_packets: %{}, # %{addr => %{seq_num => {data, dest, sent_time, retries}}}
      processed_packets: %{} # %{addr => MapSet<seq_nums>}
    }

    # Start the retry checker
    schedule_retry_check()

    {:ok, state}
  end

  @impl true
  def handle_cast({:register, addr, seq_num, data, dest}, state) do
    now = :os.system_time(:millisecond)

    # Get or create the map for this address
    addr_map = Map.get(state.pending_packets, addr, %{})

    # Add the packet to the pending list
    updated_addr_map = Map.put(addr_map, seq_num, {data, dest, now, 0})

    # Update state
    updated_pending = Map.put(state.pending_packets, addr, updated_addr_map)

    {:noreply, %{state | pending_packets: updated_pending}}
  end

  @impl true
  def handle_cast({:ack, addr, seq_num}, state) do
    # Get the map for this address
    addr_map = Map.get(state.pending_packets, addr, %{})

    # Remove the packet as it's been acknowledged
    if Map.has_key?(addr_map, seq_num) do
      updated_addr_map = Map.delete(addr_map, seq_num)

      # Update state
      updated_pending = Map.put(state.pending_packets, addr, updated_addr_map)

      Logger.debug("Packet #{seq_num} acknowledged by #{addr}")

      {:noreply, %{state | pending_packets: updated_pending}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:retry, socket}, state) do
    now = :os.system_time(:millisecond)

    # Process each address
    updated_pending = Enum.reduce(state.pending_packets, %{}, fn {addr, addr_map}, acc ->
      # Process each packet for this address
      {updated_addr_map, _} = Enum.reduce(addr_map, {%{}, 0}, fn {seq_num, {data, dest = {ip, port}, sent_time, retries}}, {acc_map, retried_count} ->
        # Check if it's time to retry
        if now - sent_time > @retry_interval do
          if retries < @max_retries do
            # Resend the packet
            packet = Net.Reliability.Packet.build_packet_with_seq(data, seq_num)
            :ok = :gen_udp.send(socket, ip, port, packet)

            Logger.debug("Retrying packet #{seq_num} to #{addr}, attempt #{retries + 1}")

            # Update sent time and retry count
            {Map.put(acc_map, seq_num, {data, dest, now, retries + 1}), retried_count + 1}
          else
            Logger.warning("Packet #{seq_num} to #{addr} timed out after #{@max_retries} retries")
            {acc_map, retried_count} # Drop the packet
          end
        else
          # Not time to retry yet
          {Map.put(acc_map, seq_num, {data, dest, sent_time, retries}), retried_count}
        end
      end)

      # Only keep the address entry if there are still packets pending
      if map_size(updated_addr_map) > 0 do
        Map.put(acc, addr, updated_addr_map)
      else
        acc
      end
    end)

    # Schedule next check
    schedule_retry_check()

    {:noreply, %{state | pending_packets: updated_pending}}
  end

  @impl true
  def handle_cast({:mark_processed, addr, seq_num}, state) do
    # Get or create the set for this address
    addr_set = Map.get(state.processed_packets, addr, MapSet.new())

    # Add the sequence number to the set
    updated_addr_set = MapSet.put(addr_set, seq_num)

    # Update state
    _ = Map.put(state.processed_packets, addr, updated_addr_set)

    # Limit the size of processed packets history (keep last 1000)
    trimmed_set = if MapSet.size(updated_addr_set) > 1000 do
      {to_remove, _} = Enum.split(Enum.sort(updated_addr_set), MapSet.size(updated_addr_set) - 1000)
      Enum.reduce(to_remove, updated_addr_set, fn seq, set -> MapSet.delete(set, seq) end)
    else
      updated_addr_set
    end

    final_processed = Map.put(state.processed_packets, addr, trimmed_set)

    {:noreply, %{state | processed_packets: final_processed}}
  end

  @impl true
  def handle_call({:processed?, addr, seq_num}, _from, state) do
    # Get the set for this address
    addr_set = Map.get(state.processed_packets, addr, MapSet.new())

    # Check if the sequence number is in the set
    result = MapSet.member?(addr_set, seq_num)

    {:reply, result, state}
  end

  @impl true
  def handle_info(:check_retransmissions, state) do
    now = :os.system_time(:millisecond)

    # Process each address
    updated_pending = Enum.reduce(state.pending_packets, %{}, fn {addr, addr_map}, acc ->
      # Process each packet for this address
      {updated_addr_map, _} = Enum.reduce(addr_map, {%{}, 0}, fn {seq_num, {data, dest, sent_time, retries}}, {acc_map, retried_count} ->
        # Check if it's time to retry
        if now - sent_time > @retry_interval do
          if retries < @max_retries do
            Logger.debug("Packet #{seq_num} to #{addr} needs retransmission")
            {Map.put(acc_map, seq_num, {data, dest, sent_time, retries}), retried_count + 1}
          else
            Logger.warning("Packet #{seq_num} to #{addr} timed out after #{@max_retries} retries")
            {acc_map, retried_count} # Drop the packet
          end
        else
          # Not time to retry yet
          {Map.put(acc_map, seq_num, {data, dest, sent_time, retries}), retried_count}
        end
      end)

      # Only keep the address entry if there are still packets pending
      if map_size(updated_addr_map) > 0 do
        Map.put(acc, addr, updated_addr_map)
      else
        acc
      end
    end)

    # Schedule next check
    schedule_retry_check()

    {:noreply, %{state | pending_packets: updated_pending}}
  end

  defp schedule_retry_check do
    Process.send_after(__MODULE__, :check_retransmissions, @retry_interval)
  end
end
