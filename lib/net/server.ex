defmodule Net.Server do
  use GenServer
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  alias Net.Packet.{Builder, Data, Login, Request, Response, Update}
  alias Net.{Cluster, Reliability.Packet, Reliability.Parser}
  alias Net.Conn
  alias Net.Reliability.Manager, as: ReliabilityManager
  alias Net.Conn.Manager, as: ConnManager
  alias Net.Service.AuthLimiter
  alias Net.Service.Registry
  alias Prism.Handler.Context

  require Logger

  def start_link(opts) do
    port = opts[:port]
    region = opts[:region]

    Cluster.connect(%{
      address: region,
      peers:
        Application.get_env(:prism, :regions)
        |> Enum.find(fn {_key, cfg} -> cfg.address == region end)
        |> elem(1)
        |> Map.get(:peers, [])
    })

    GenServer.start_link(__MODULE__, %{port: port, region: region}, name: {:global, region})
  end

  def send_to_conn(%Conn{} = conn, message) when is_binary(message) do
    {ip, port} = Conn.destination(conn)
    region = Prism.current_region()

    case :global.whereis_name(region) do
      pid when pid == self() ->
        send(self(), {:send_reliable_async, ip, port, message})
        :ok

      _pid ->
        GenServer.call({:global, region}, {:send_reliable, ip, port, message})
    end
  end

  @impl true
  def init(%{port: port, region: region} = state) do
    Logger.debug("UDP Server listening on port #{port} in region #{region}")

    case :gen_udp.open(port, [:binary, active: true]) do
      {:ok, socket} ->
        ReliabilityManager.set_socket(socket)
        {:ok, Map.put(state, :socket, socket)}

      {:error, reason} ->
        Logger.error("Failed to open UDP socket on port #{port}: #{inspect(reason)}")
        {:stop, {:udp_open_failed, reason}}
    end
  end

  @impl true
  def handle_info({:udp, _socket, ip, port, data}, state) do
    start_time = System.monotonic_time()
    addr = format_address(ip, port)
    buffer = :erlang.iolist_to_binary(data)

    case Parser.parse_packet(buffer) do
      {:ack, seq} ->
        :telemetry.execute([:prism, :packet, :ingress], %{count: 1}, %{type: :ack, address: addr})
        ReliabilityManager.acknowledge_packet(addr, seq)

        :telemetry.execute(
          [:prism, :packet, :processing],
          %{duration: System.monotonic_time() - start_time},
          %{result: :ok, type: :ack}
        )

        {:noreply, state}

      {:data, seq, payload, _checksum} ->
        :telemetry.execute([:prism, :packet, :ingress], %{count: 1}, %{type: :data, address: addr})

        send_ack(state.socket, ip, port, seq)

        unless ReliabilityManager.already_processed?(addr, seq) do
          ReliabilityManager.mark_as_processed(addr, seq)
          conn = ConnManager.get_connection(addr)

          if conn do
            handle_packet_sequence(ip, port, payload, conn)
          else
            handle_login_sequence(state.socket, ip, port, payload)
          end
        end

        :telemetry.execute(
          [:prism, :packet, :processing],
          %{duration: System.monotonic_time() - start_time},
          %{result: :ok, type: :data}
        )

        {:noreply, state}

      {:error, :invalid_key_size, size} ->
        Logger.warning("Received packet with invalid key size (#{size}) from #{addr}")

        :telemetry.execute([:prism, :packet, :decode_error], %{count: 1}, %{
          reason: :invalid_key_size
        })

        {:noreply, state}

      {:error, :decryption_failed} ->
        Logger.warning("Decryption failed for packet from #{addr}")

        :telemetry.execute([:prism, :packet, :decode_error], %{count: 1}, %{
          reason: :decryption_failed
        })

        {:noreply, state}

      {:error, :invalid_checksum, expected, received} ->
        Logger.warning(
          "Invalid checksum for packet from #{addr} (Exp: #{inspect(expected)} | Recv: #{inspect(received)})"
        )

        :telemetry.execute([:prism, :packet, :decode_error], %{count: 1}, %{
          reason: :invalid_checksum
        })

        {:noreply, state}

      {:error, :invalid_packet_format} ->
        Logger.warning("Invalid packet format from #{addr}")

        :telemetry.execute([:prism, :packet, :decode_error], %{count: 1}, %{
          reason: :invalid_packet_format
        })

        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:send_reliable_async, ip, port, message}, state) do
    _ = send_reliable(state.socket, ip, port, message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp_error, _socket, reason}, state) do
    log_udp_error(reason, state)

    :telemetry.execute([:prism, :packet, :socket_error], %{count: 1}, %{
      reason: reason,
      region: state.region,
      port: state.port
    })

    {:noreply, state}
  end

  @impl true
  def handle_info({:enforce_handler_timeout, pid, route}, state) do
    if Process.alive?(pid) do
      Process.exit(pid, :kill)
      Logger.warning("Handler #{inspect(route)} exceeded timeout and was terminated")

      :telemetry.execute([:prism, :handler, :timeout], %{count: 1}, %{route: inspect(route)})
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:update, %{from: from, data: data}}, _from, state) do
    Logger.debug("Background update from #{from}: #{inspect(data)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update, data}, _from, state) do
    Logger.debug("Background update: #{inspect(data)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:send_reliable, ip, port, message}, _from, state) do
    {:reply, send_reliable(state.socket, ip, port, message), state}
  end

  defp handle_login_sequence(socket, ip, port, data) do
    addr = format_address(ip, port)

    with {:ok, packet} <- Parser.try_decode(&Login.decode/1, data, addr) do
      service = Registry.get_service(packet.service)
      service_options = service_options(service)

      case AuthLimiter.allow_login?(packet.service, addr, service_options) do
        :ok ->
          verify_login(socket, ip, port, addr, packet)

        {:error, :rate_limited} ->
          pk = Builder.auth_response(Response.rate_limited(), Response.failure())
          send_reliable(socket, ip, port, pk)

          :telemetry.execute([:prism, :auth, :result], %{count: 1}, %{
            status: :rate_limited,
            service: packet.service
          })
      end
    else
      _ ->
        with {:ok, _} <- Parser.try_decode(&Data.decode/1, data, addr) do
          Logger.debug("Received data packet from #{addr} before login")
          pk = Builder.auth_response(Response.login_required(), Response.failure())
          send_reliable(socket, ip, port, pk)
          :telemetry.execute([:prism, :auth, :result], %{count: 1}, %{status: :login_required})
        else
          _ ->
            Logger.debug("Invalid packet from #{addr}")
            pk = Builder.auth_response(Response.invalid_packet(), Response.failure())
            send_reliable(socket, ip, port, pk)
            :telemetry.execute([:prism, :auth, :result], %{count: 1}, %{status: :invalid_packet})
        end
    end
  end

  defp handle_packet_sequence(ip, port, data, conn) do
    addr = format_address(ip, port)

    with {:ok, packet} <- Parser.try_decode(&Data.decode/1, data, addr) do
      %Data{type: type} = packet
      service = Registry.get_service(conn.service)

      if service && type in service.valid_packets do
        Logger.debug("Packet received from #{addr} with type #{type}")

        routes = route_candidates(packet)

        case Net.Service.Dispatch.get_handler(conn.service, routes) do
          nil ->
            Logger.debug("No handler registered for #{inspect(routes)}")

          handler_spec ->
            context = Context.new(conn, packet, handler_spec.route)
            dispatch_handler(handler_spec, context)
        end
      else
        if service == nil do
          Logger.debug(
            "Packet received from #{addr} with type #{type} from invalid service (#{conn.service})"
          )
        else
          Logger.debug(
            "Packet received from #{addr} with type #{type} is not valid for the service (#{conn.service}) [#{inspect(service.valid_packets)}]."
          )
        end
      end
    else
      _ -> Logger.debug("Invalid packet from #{addr}")
    end
  end

  defp send_ack(socket, ip, port, seq) do
    ack_packet = Packet.build_ack_packet(seq)
    :gen_udp.send(socket, ip, port, ack_packet)
  end

  defp send_reliable(socket, ip, port, message) do
    {seq, packet} = Packet.build_packet(message)
    addr = format_address(ip, port)

    case ReliabilityManager.register_packet(addr, seq, message, {ip, port}) do
      :ok ->
        :gen_udp.send(socket, ip, port, packet)
        {:ok, seq}

      {:error, :backpressure} = error ->
        error
    end
  end

  defp verify_login(socket, ip, port, addr, packet) do
    case Registry.verify_service(packet.service, packet.token) do
      :ok ->
        Logger.debug("Valid login packet received from #{addr} (service: #{packet.service})")
        AuthLimiter.clear(packet.service, addr)
        ConnManager.add_connection(Conn.new(addr, true, packet.service))
        pk = Builder.auth_response(Response.ok(), Response.success())
        send_reliable(socket, ip, port, pk)

        :telemetry.execute([:prism, :auth, :result], %{count: 1}, %{
          status: :ok,
          service: packet.service
        })

      {:error, :invalid_credentials} ->
        Logger.debug(
          "Invalid login packet (credentials) received from #{addr} (service: #{packet.service})"
        )

        AuthLimiter.record_failure(packet.service, addr)
        pk = Builder.auth_response(Response.invalid_credentials(), Response.failure())
        send_reliable(socket, ip, port, pk)

        :telemetry.execute(
          [:prism, :auth, :result],
          %{count: 1},
          %{status: :invalid_credentials, service: packet.service}
        )

      {:error, :invalid_service} ->
        Logger.debug(
          "Invalid login packet (service) received from #{addr} (service: #{packet.service})"
        )

        AuthLimiter.record_failure(packet.service, addr)
        pk = Builder.auth_response(Response.invalid_service(), Response.failure())
        send_reliable(socket, ip, port, pk)

        :telemetry.execute(
          [:prism, :auth, :result],
          %{count: 1},
          %{status: :invalid_service, service: packet.service}
        )
    end
  end

  defp route_candidates(%Data{type: type, payload: {:request, %Request{type: request_type}}}) do
    [{:request, request_type}, {:packet, type}]
  end

  defp route_candidates(%Data{type: type, payload: {:update, %Update{type: update_type}}}) do
    [{:update, update_type}, {:packet, type}]
  end

  defp route_candidates(%Data{type: type}) do
    [{:packet, type}]
  end

  defp dispatch_handler(handler_spec, context) do
    run_handler = fn -> execute_handler(handler_spec, context) end

    if handler_spec.async? do
      {:ok, pid} = Task.Supervisor.start_child(Prism.HandlerSupervisor, run_handler)

      Process.send_after(
        self(),
        {:enforce_handler_timeout, pid, handler_spec.route},
        handler_spec.timeout
      )
    else
      run_handler.()
    end
  end

  defp execute_handler(handler_spec, context) do
    handler_start = System.monotonic_time()

    try do
      result = Net.Service.Dispatch.invoke(handler_spec, context)
      handle_handler_result(context, result)

      :telemetry.execute(
        [:prism, :handler, :duration],
        %{duration: System.monotonic_time() - handler_start},
        %{type: context.packet_type, service: context.service, route: inspect(handler_spec.route)}
      )
    rescue
      exception ->
        Logger.error(
          "Handler #{inspect(handler_spec.route)} failed: #{Exception.format(:error, exception, __STACKTRACE__)}"
        )

        :telemetry.execute(
          [:prism, :handler, :error],
          %{count: 1},
          %{route: inspect(handler_spec.route), service: context.service}
        )
    end
  end

  defp handle_handler_result(_context, :ok), do: :ok
  defp handle_handler_result(_context, nil), do: :ok

  defp handle_handler_result(context, {:reply, message}) when is_binary(message) do
    Prism.reply(context.conn, message)
  end

  defp handle_handler_result(context, {:json, payload}) do
    Prism.json_reply(context.conn, payload)
  end

  defp handle_handler_result(context, {:json, payload, opts}) do
    Prism.json_reply(context.conn, payload, opts)
  end

  defp handle_handler_result(_context, {:broadcast, data}) do
    Prism.broadcast_update(data)
  end

  defp handle_handler_result(_context, _result), do: :ok

  defp service_options(%{options: options}) when is_map(options), do: Map.to_list(options)
  defp service_options(_), do: []

  defp log_udp_error(:econnreset, %{port: port, region: region}) do
    Logger.debug("Ignoring UDP socket reset on port #{port} in region #{region}")
  end

  defp log_udp_error(reason, %{port: port, region: region}) do
    Logger.warning("UDP socket error on port #{port} in region #{region}: #{inspect(reason)}")
  end

  defp format_address(ip, port) do
    ip_string = ip |> :inet.ntoa() |> to_string()
    "#{ip_string}:#{port}"
  end
end
