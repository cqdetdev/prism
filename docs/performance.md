# Performance tooling

## TypeScript UDP load generator

Script: `client/ts/loadtest.ts`

Run:

```bash
cd client/ts
bun install
bun run loadtest
```

Environment variables:

- `PRISM_HOST` (default `127.0.0.1`)
- `PRISM_PORT` (default `6969`)
- `PRISM_KEY` (default matches `config :prism, :key`)
- `PRISM_CLIENTS` (default `10`)
- `PRISM_REQUESTS_PER_CLIENT` (default `100`)

## Server-side telemetry + periodic snapshots

`Prism.Metrics.Reporter` attaches to `:telemetry` events emitted by Prism and logs a snapshot every 10s.

From a running node:

```elixir
Prism.Metrics.snapshot()
```

Runtime health:

```elixir
Prism.health()
```

## Micro-benchmarks

Script: `bench/packet_pipeline.exs`

Run:

```bash
mix deps.get
mix run bench/packet_pipeline.exs
```

## Windows note (`mix run -e ...`)

On Windows PowerShell, `mix run -e "..."` can be parsed incorrectly and may not boot the Mix project the way you expect.

Prefer one of:

- `mix run path/to/script.exs`
- `iex -S mix` then run Elixir code interactively
