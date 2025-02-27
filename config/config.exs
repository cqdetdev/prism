import Config

config :prism, ecto_repos: [Data.Repo]

config :prism, Data.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "Wallah123",
  database: "oomf",
  hostname: "127.0.0.1",
  pool_size: 10
