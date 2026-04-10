# Service API

Prism now supports two ways to define services:

1. A **declarative service module DSL** using `use Prism.Service`
2. An **imperative runtime API** using `Prism.register_service/3`

## Recommended: service module DSL

```elixir
defmodule MyApp.InventoryService do
  use Prism.Service,
    name: "inventory",
    token: "super-secret-token",
    login_rate_limit: [max_attempts: 15, window_ms: 60_000]

  alias Prism.Handler.Context

  handle_request(100, :list_items)
  handle_update("stock", :handle_stock_update, async: true, timeout: 2_000)

  def list_items(context) do
    Context.json_reply(context, %{items: [%{sku: "abc", qty: 10}]}, message: "ITEMS_OK")
  end

  def handle_stock_update(context) do
    update = Context.update(context)
    Context.broadcast(context, %{from: context.service, data: %{sku: update.name, qty: update.value}})
    :ok
  end
end
```

Register the service in config:

```elixir
config :prism, :services, [
  Prism.Service.Default,
  MyApp.InventoryService
]
```

For a complete real example, see:

- `Prism.Examples.PracticeService`
- `docs/minecraft_practice.md`

## Imperative API

If you prefer to register routes at runtime:

```elixir
Prism.register_service("inventory", "super-secret-token",
  login_rate_limit: [max_attempts: 15, window_ms: 60_000],
  routes: [
    Prism.Service.request(100, fn context ->
      Prism.json_reply(context, %{items: [%{sku: "abc", qty: 10}]}, message: "ITEMS_OK")
    end),
    Prism.Service.update("stock", {MyApp.InventoryHandlers, :handle_stock_update}, async: true)
  ]
)
```

## Handler context

Handlers receive a `Prism.Handler.Context` with:

- `conn` - the authenticated `Net.Conn`
- `service` - the registered service name
- `packet` - the decoded `Net.Packet.Data`
- `packet_type` - the top-level packet type
- `payload_kind` - `:request`, `:update`, etc.
- `payload` - the decoded nested packet
- `route` - the matched dispatch route

Helper functions:

- `Prism.Handler.Context.request/1`
- `Prism.Handler.Context.update/1`
- `Prism.Handler.Context.decode_json/1`
- `Prism.Handler.Context.reply/2`
- `Prism.Handler.Context.json_reply/3`
- `Prism.Handler.Context.broadcast/2`

## Handler return values

Handlers may:

- return `:ok` / `nil`
- return `{:reply, encoded_binary_packet}`
- return `{:json, map}` or `{:json, map, opts}`
- return `{:broadcast, data}`
- call the context helper functions directly

## Dispatch routes

Supported routes:

- `{:request, request_type}`
- `{:update, update_type}`
- `{:packet, packet_type}`

Dispatch resolution order is:

1. service-specific route
2. wildcard route (`:*`)
3. no match

## Default service

`Prism.Service.Default` is registered by default and handles the built-in request packet IDs:

- `create_user`
- `get_all_users`
- `get_all_staff`
- `get_ordered_by_kills`
- `get_ordered_by_deaths`
