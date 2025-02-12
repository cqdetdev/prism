import Config

config :tcp_listener, port: 6969

config :oomf, ecto_repos: [Data.Repo]

config :oomf, Data.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "Wallah123",
  database: "oomf",
  hostname: "127.0.0.1",
  pool_size: 10
