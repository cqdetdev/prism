defmodule Data.Repo do
  use Ecto.Repo,
    otp_app: :oomf,
    adapter: Ecto.Adapters.Postgres
end
