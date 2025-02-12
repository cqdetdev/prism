defmodule Oomf do
  @moduledoc """
  Contains all the logic for the broker. Including the listener, and database.
  """
  use Application

  def start(_type, _args) do
    port = 6969
    children = [
      {Net.Server, port},
      {Data.Repo, []},
      {Redix, name: :redix},
      {Net.Manager, []},
    ]

    opts = [strategy: :one_for_one, name: Net.Listener.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
