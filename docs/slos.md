# SLO starter targets (calibrate with your hardware + traffic)

These are **starting points** for local benchmarking, not production promises.

## Client-visible reliability

- **ACK timeout rate**: `< 0.5%` under steady-state UDP load on a LAN loopback test
- **p95 end-to-end `send()` latency** (client timer): `< 25ms` on loopback for small payloads

## Server processing

- **p95 `[:prism, :packet, :processing]` duration**: `< 5ms` on loopback for small payloads
- **Decode error rate** (`[:prism, :packet, :decode_error]` / ingress): `< 0.01%` for valid clients

## Reliability subsystem

- **Retry rate** (`[:prism, :reliability, :retry]` / successful sends): `< 1%` under normal loss
- **Server-side timeout rate** (`[:prism, :reliability, :timeout]`): `0` in healthy networks

## Cluster fanout

- **Broadcast failure rate** (`[:prism, :cluster, :broadcast_failure]` / attempts): `< 1%` when peers are up

## How to measure

- Run `client/ts/loadtest.ts` while watching server logs for `Metrics snapshot ...` lines.
- For deeper inspection, attach temporary `:telemetry` handlers in `iex`.
