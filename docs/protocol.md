# Protocol notes

## Reliable UDP framing

Prism reliable data packets use:

```text
<TYPE:1><SEQ:4><CHECKSUM:4><IV:12><CIPHERTEXT:*><TAG:16>
```

Where:

- `TYPE=1` means reliable data
- `TYPE=2` means ACK and is encoded as `<TYPE:1><SEQ:4>`
- `CHECKSUM` is computed over the **decrypted payload**
- `IV/CIPHERTEXT/TAG` are AES-256-GCM encrypted payload bytes

## Packet IDs inside `Net.Packet.Data`

- `2` = login (`Net.Packet.Login`)
- `3` = auth response (`Net.Packet.Response`)
- `4` = update (`Net.Packet.Update`)
- `5` = request (`Net.Packet.Request`)
- `6` = service response (`Net.Packet.ServiceResponse`)

## Service routing

Once a service is authenticated, Prism routes packets by:

- `{:request, request.type}` for `Net.Packet.Request`
- `{:update, update.type}` for `Net.Packet.Update`
- `{:packet, data.type}` as a top-level fallback

That means custom services can expose their own request/update namespaces without patching the core server.

## Generic service responses

Custom handlers can reply with `Net.Packet.ServiceResponse` through:

```elixir
Prism.json_reply(conn_or_context, %{ok: true}, message: "OK")
```

This wraps your JSON payload in a generic response packet so custom services can return data without needing a brand new protobuf message for every endpoint.
