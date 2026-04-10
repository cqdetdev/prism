# Minecraft Practice Sample App

Prism now ships with a sample service for a Minecraft practice server:

- service: `practice_service`
- token: `practice_token`
- module: `Prism.Examples.PracticeService`

It is enabled by default in `config/config.exs` and `config/config.example.exs`.

## What it stores

The sample uses the `users` table and extends `Data.User` with practice-specific fields:

- `wins`
- `losses`
- `matches_played`
- `elo`
- `best_elo`
- `current_streak`
- `best_streak`
- `queue_ratings`
- `kit_stats`
- `practice_metadata`
- `last_seen_region`

Run the migration:

```bash
mix ecto.migrate
```

## Routes

### Request routes

- `1000` `upsert_player`
- `1001` `player_profile`
- `1002` `leaderboard`

### Update routes

- `"practice_match_result"`
- `"practice_queue_rating"`
- `"practice_presence"`

## Request payloads

### Upsert player

```json
{
  "username": "PvPAlpha",
  "xuid": "xuid-alpha",
  "display_name": "PvP Alpha",
  "region": "NA1",
  "language": "en_US",
  "device_id": "bedrock-device-001"
}
```

### Player profile

```json
{
  "username": "PvPAlpha"
}
```

or

```json
{
  "xuid": "xuid-alpha"
}
```

### Leaderboard

```json
{
  "metric": "elo",
  "limit": 10,
  "offset": 0
}
```

Supported metrics:

- `"elo"`
- `"wins"`
- `"kills"`
- `"streak"`

## Update payloads

### Match result

```json
{
  "queue": "no_debuff",
  "region": "NA1",
  "duration_seconds": 180,
  "winner": {
    "username": "PvPAlpha",
    "kills": 1,
    "deaths": 0
  },
  "loser": {
    "username": "PvPBeta",
    "kills": 0,
    "deaths": 1
  }
}
```

This:

- increments wins/losses
- updates total kills/deaths
- updates streaks
- updates overall elo
- updates queue-specific ratings in `queue_ratings`
- updates per-kit/per-queue aggregate stats in `kit_stats`
- broadcasts a cluster update with the match summary

### Queue rating override

```json
{
  "username": "PvPAlpha",
  "queue": "sumo",
  "rating": 1425,
  "region": "NA1"
}
```

### Presence / session heartbeat

```json
{
  "username": "PvPAlpha",
  "display_name": "PvP Alpha",
  "region": "NA1",
  "playtime_delta": 300,
  "language": "en_US",
  "practice_metadata": {
    "last_arena": "castle",
    "party_size": 1
  }
}
```

## Run the demo client

```bash
cd client/ts
bun install
bun run practice:demo
```

The demo will:

1. log in to `practice_service`
2. create/update two players
3. record a duel result
4. request the elo leaderboard

Service responses print in the TS client through the generic `service_response` packet.
