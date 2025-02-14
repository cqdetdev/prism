import Config

config :oomf, ecto_repos: [Data.Repo]

config :oomf, Data.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "Test123",
  database: "oomf",
  hostname: "127.0.0.1",
  pool_size: 10
