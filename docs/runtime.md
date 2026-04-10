# Runtime and operations

## Runtime config

Prism now supports runtime overrides via `config/runtime.exs`.

Environment variables:

- `PRISM_KEY`
- `PRISM_START_UDP`
- `PRISM_START_DATABASE`
- `PRISM_START_REDIS`
- `PRISM_START_CLUSTER`
- `PRISM_METRICS_REPORTER`
- `PRISM_DB_USERNAME`
- `PRISM_DB_PASSWORD`
- `PRISM_DB_NAME`
- `PRISM_DB_HOST`
- `PRISM_DB_POOL_SIZE`

This lets you keep `config/config.exs` as a sane default while overriding secrets and deployment toggles in production.

## Health snapshot

Use the runtime health API from `iex -S mix`:

```elixir
Prism.health()
```

Example shape:

```elixir
%{
  status: :ok,
  region: :"na1@127.0.0.1",
  udp: :ok,
  database: :ok,
  redis: :ok,
  cluster: %{enabled: true, connected_nodes: [:"eu1@127.0.0.1"]},
  services: ["default_service"],
  metrics: %{...}
}
```

## Auth hardening

Login attempts are rate-limited through `Net.Service.AuthLimiter`.

Defaults:

- `max_attempts: 10`
- `window_ms: 60_000`

Override globally:

```elixir
config :prism, :auth_rate_limit, max_attempts: 20, window_ms: 60_000
```

Override per service:

```elixir
use Prism.Service,
  name: "inventory",
  token: "secret",
  login_rate_limit: [max_attempts: 30, window_ms: 60_000]
```

## Reliability backpressure

Outgoing reliable packets are capped to keep queues bounded.

Defaults:

- `:max_pending_packets` = `10_000`
- `:max_pending_per_address` = `1_000`

When limits are exceeded Prism drops the registration attempt and emits:

- `[:prism, :reliability, :backpressure_drop]`

## Handler isolation

Route handlers run under `Task.Supervisor` by default and emit:

- `[:prism, :handler, :duration]`
- `[:prism, :handler, :error]`
- `[:prism, :handler, :timeout]`

Timeouts are controlled by:

```elixir
config :prism, :handler_timeout_ms, 5_000
```
