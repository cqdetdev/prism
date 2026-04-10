defmodule Net.Reliability.Manager do
  use GenServer
  require Logger

  @retry_interval 500
  @max_retries 5

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def register_packet(addr, seq_num, data, dest) do
    GenServer.call(__MODULE__, {:register, addr, seq_num, data, dest})
  end

  def acknowledge_packet(addr, seq_num) do
    GenServer.cast(__MODULE__, {:ack, addr, seq_num})
  end

  def process_retransmissions(socket) do
    GenServer.cast(__MODULE__, {:retry, socket})
  end

  def set_socket(socket) do
    GenServer.cast(__MODULE__, {:set_socket, socket})
  end

  def already_processed?(addr, seq_num) do
    GenServer.call(__MODULE__, {:processed?, addr, seq_num})
  end

  def mark_as_processed(addr, seq_num) do
    GenServer.cast(__MODULE__, {:mark_processed, addr, seq_num})
  end

  @impl true
  def init(_) do
    {:ok,
     %{
       # %{addr => %{seq_num => {data, dest, due_time_ms, retries}}}
       pending_packets: %{},
       # %{addr => MapSet<seq_num>}
       processed_packets: %{},
       pending_count: 0,
       socket: nil,
       retry_timer_ref: nil
     }}
  end

  @impl true
  def handle_call({:register, addr, seq_num, data, dest}, _from, state) do
    {max_pending_packets, max_pending_per_address} = reliability_limits()
    per_address_count = state.pending_packets |> Map.get(addr, %{}) |> map_size()

    cond do
      state.pending_count >= max_pending_packets ->
        emit_backpressure(addr, seq_num, :global_limit)
        {:reply, {:error, :backpressure}, state}

      per_address_count >= max_pending_per_address ->
        emit_backpressure(addr, seq_num, :address_limit)
        {:reply, {:error, :backpressure}, state}

      true ->
        now = :os.system_time(:millisecond)
        due_time = now + @retry_interval

        updated_pending =
          state.pending_packets
          |> Map.update(
            addr,
            %{seq_num => {data, dest, due_time, 0}},
            &Map.put(&1, seq_num, {data, dest, due_time, 0})
          )

        next_state =
          %{
            state
            | pending_packets: updated_pending,
              pending_count: pending_count(updated_pending)
          }
          |> schedule_next_retry()

        {:reply, :ok, next_state}
    end
  end

  @impl true
  def handle_call({:processed?, addr, seq_num}, _from, state) do
    result = Map.get(state.processed_packets, addr, MapSet.new()) |> MapSet.member?(seq_num)
    {:reply, result, state}
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

    {:noreply,
     %{state | pending_packets: updated_pending, pending_count: pending_count(updated_pending)}
     |> schedule_next_retry()}
  end

  @impl true
  def handle_cast({:retry, socket}, state) do
    state
    |> Map.put(:socket, socket || state.socket)
    |> retry_due_packets()
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_cast({:set_socket, socket}, state) do
    {:noreply, %{state | socket: socket}}
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
  def handle_info(:check_retransmissions, state) do
    state
    |> Map.put(:retry_timer_ref, nil)
    |> retry_due_packets()
    |> then(&{:noreply, &1})
  end

  defp retry_due_packets(state) do
    socket = state.socket
    now = :os.system_time(:millisecond)

    updated_pending =
      Enum.reduce(state.pending_packets, %{}, fn {addr, addr_map}, acc ->
        updated_addr_map =
          Enum.reduce(addr_map, %{}, fn {seq_num, {data, {ip, port} = dest, due_time, retries}},
                                        acc_map ->
            if due_time <= now do
              if retries < @max_retries do
                packet = Net.Reliability.Packet.build_packet_with_seq(data, seq_num)

                if socket do
                  :ok = :gen_udp.send(socket, ip, port, packet)
                end

                Logger.debug("Retrying packet #{seq_num} to #{addr}, attempt #{retries + 1}")

                :telemetry.execute(
                  [:prism, :reliability, :retry],
                  %{count: 1},
                  %{address: addr, sequence: seq_num, attempt: retries + 1}
                )

                Map.put(acc_map, seq_num, {data, dest, now + @retry_interval, retries + 1})
              else
                Logger.warning(
                  "Packet #{seq_num} to #{addr} timed out after #{@max_retries} retries"
                )

                :telemetry.execute(
                  [:prism, :reliability, :timeout],
                  %{count: 1},
                  %{address: addr, sequence: seq_num}
                )

                acc_map
              end
            else
              Map.put(acc_map, seq_num, {data, dest, due_time, retries})
            end
          end)

        if map_size(updated_addr_map) > 0 do
          Map.put(acc, addr, updated_addr_map)
        else
          acc
        end
      end)

    %{state | pending_packets: updated_pending, pending_count: pending_count(updated_pending)}
    |> schedule_next_retry()
  end

  defp schedule_next_retry(state) do
    if state.retry_timer_ref do
      Process.cancel_timer(state.retry_timer_ref)
    end

    case next_due_in_ms(state.pending_packets) do
      nil ->
        %{state | retry_timer_ref: nil}

      delay ->
        ref = Process.send_after(self(), :check_retransmissions, delay)
        %{state | retry_timer_ref: ref}
    end
  end

  defp next_due_in_ms(pending_packets) do
    now = :os.system_time(:millisecond)

    delays =
      pending_packets
      |> Enum.flat_map(fn {_addr, packet_map} -> Map.values(packet_map) end)
      |> Enum.map(fn {_data, _dest, due_time, _retries} -> max(due_time - now, 0) end)

    case delays do
      [] -> nil
      _ -> Enum.min(delays)
    end
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

  defp reliability_limits do
    {
      Application.get_env(:prism, :max_pending_packets, 10_000),
      Application.get_env(:prism, :max_pending_per_address, 1_000)
    }
  end

  defp pending_count(pending_packets) do
    Enum.reduce(pending_packets, 0, fn {_addr, addr_map}, acc -> acc + map_size(addr_map) end)
  end

  defp emit_backpressure(addr, seq_num, scope) do
    Logger.warning("Dropping packet #{seq_num} for #{addr} due to #{scope} backpressure")

    :telemetry.execute(
      [:prism, :reliability, :backpressure_drop],
      %{count: 1},
      %{address: addr, sequence: seq_num, scope: scope}
    )
  end
end
