import Config

config :prism, ecto_repos: [Data.Repo]

config :prism, Data.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "test123",
  database: "test",
  hostname: "127.0.0.1",
  pool_size: 10

config :prism, :regions, %{
  "NA1" => %{address: :"na1@127.0.0.1", port: 6969, peers: [:"eu1@127.0.0.1"]},
  "NA2" => %{address: :"na2@127.0.0.1", port: 6969, peers: [:"eu2@127.0.0.1"]},
  "EU1" => %{address: :"eu1@127.0.0.1", port: 7979, peers: [:"na1@127.0.0.1"]},
  "EU2" => %{address: :"eu2@127.0.0.1", port: 7979, peers: [:"na2@127.0.0.1"]},
  "AS" => %{address: :"as@127.0.0.1", port: 8989, peers: [:"na@127.0.0.1", :"eu@127.0.0.1"]}
}

config :prism, :key, "secret-auth-key-123============="

config :prism,
  start_udp: true,
  start_database: true,
  start_redix: true,
  start_cluster: true

config :prism, :metrics_reporter, true
config :prism, :services, [Prism.Service.Default, Prism.Examples.PracticeService]
config :prism, :handler_timeout_ms, 5_000
config :prism, :auth_rate_limit, max_attempts: 10, window_ms: 60_000
config :prism, :max_pending_packets, 10_000
config :prism, :max_pending_per_address, 1_000

import_config "#{config_env()}.exs"
