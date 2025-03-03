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
