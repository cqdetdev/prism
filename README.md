# Prism

A simple, fast, and distributed data broker for clustered server use.

<div style="text-align: right;">
  <img height="128" alt="image" src="./assets/logo.jpg">
</div>

## Purpose

The typical problem with distributed servers is encountering the three main issues:
- The server typically has to rely on a central DB server (which adds latency to farther regions)
- A server that does use distributed DBs needs to handle synchronization between the DBs (which is hard to do correctly)
- Database mutations and queries are typically slow and asynchronous operations are difficult to implement correctly

Thus, the solution is to use a broker to extract all the database logic. However, we want a distributed broker
so that we are able to limit latency but also have some way to handle synchronization between the brokers.

## Architecture

![Architecture](/assets/diagram.png)

## Features/Development

- `Net.Server` - central server to handle all UDP traffic
- `Net.Manager` - central manager to handle all connections
- `Net.Conn` - connection struct to store connection info
- `Net.Packet` - Protobuf packets to handle all the different packet types
- `Net.Cluster` - functions to connect to other nodes and broadcast updates (via OTP)
- `Net.Reliablity` - enforces reliability on all packets as well as handling retries
- `Net.Security` - utilizes AES to encrypt and decrypt incoming packets
- `Net.Dispatch` - performs/stores all packet handlers (based on an ID specified)
- `Prism.Metrics.Reporter` - aggregates `:telemetry` events into periodic snapshots
- `client/ts/loadtest.ts` - UDP load generator for quick perf smoke tests

Docs:

- `docs/performance.md`
- `docs/slos.md`
- `docs/service_api.md`
- `docs/runtime.md`
- `docs/protocol.md`
- `docs/minecraft_practice.md`

## Custom Services

Prism now supports first-class service modules. Register your services in config:

```elixir
config :prism, :services, [
  Prism.Service.Default,
  Prism.Examples.PracticeService,
  MyApp.InventoryService
]
```

Example:

```elixir
defmodule MyApp.InventoryService do
  use Prism.Service, name: "inventory", token: "secret-token"

  alias Prism.Handler.Context

  handle_request(100, :list_items)

  def list_items(context) do
    Context.json_reply(context, %{items: [%{sku: "abc", qty: 10}]}, message: "ITEMS_OK")
  end
end
```

## Sample Practice App

Prism includes a runnable sample service for a Minecraft practice server:

- service: `practice_service`
- token: `practice_token`
- docs: `docs/minecraft_practice.md`
- TS demo: `client/ts/practice-demo.ts`

It supports:

- player upsert/profile lookup
- match result recording
- elo/wins/kills/streak leaderboards
- queue-specific ratings
- session/presence updates

## Current Status

- [x] Basic UDP server
- [x] Basic packet handling
- [x] Basic cluster connection
- [x] Finish packet layer
- [x] Add service authentication
- [x] Implemented security via AES encryption
- [x] Add database connection
- [ ] Add redis connection
- [x] Add proper regional handling
- [ ] Find a way to combat synchronization issues (few will arise because of Cluster implementation)
- [x] Add better logging
