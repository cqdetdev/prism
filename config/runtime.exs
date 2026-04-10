import Config

parse_bool = fn
  nil, default -> default
  value, _default -> value in ["1", "true", "TRUE", "yes", "YES"]
end

if key = System.get_env("PRISM_KEY") do
  config :prism, :key, key
end

config :prism,
  start_udp:
    parse_bool.(System.get_env("PRISM_START_UDP"), Application.get_env(:prism, :start_udp, true)),
  start_database:
    parse_bool.(
      System.get_env("PRISM_START_DATABASE"),
      Application.get_env(:prism, :start_database, true)
    ),
  start_redix:
    parse_bool.(
      System.get_env("PRISM_START_REDIS"),
      Application.get_env(:prism, :start_redix, true)
    ),
  start_cluster:
    parse_bool.(
      System.get_env("PRISM_START_CLUSTER"),
      Application.get_env(:prism, :start_cluster, true)
    ),
  metrics_reporter:
    parse_bool.(
      System.get_env("PRISM_METRICS_REPORTER"),
      Application.get_env(:prism, :metrics_reporter, true)
    )

db_overrides =
  [
    username: System.get_env("PRISM_DB_USERNAME"),
    password: System.get_env("PRISM_DB_PASSWORD"),
    database: System.get_env("PRISM_DB_NAME"),
    hostname: System.get_env("PRISM_DB_HOST"),
    pool_size: System.get_env("PRISM_DB_POOL_SIZE")
  ]
  |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  |> Enum.map(fn
    {:pool_size, value} -> {:pool_size, String.to_integer(value)}
    pair -> pair
  end)

if db_overrides != [] do
  config :prism, Data.Repo, db_overrides
end
