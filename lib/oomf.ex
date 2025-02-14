defmodule Oomf do
  @moduledoc """
  Contains all the logic for the broker. Including the listener, and database.
  """
  use Application

  def start(_type, _args) do
    region = detect_region()
    children = [
      {Data.Repo, []},
      {Redix, name: :redix},
      {Net.Manager, []},
    ] ++ start_server(region)

    opts = [strategy: :one_for_one, name: Net.Listener.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp detect_region do
    case System.get_env("REGION") do
      "NA" -> :na
      "EU" -> :eu
      "AS" -> :as
      _ -> :unknown
    end
  end

  defp start_server(:na), do: [{Net.Server, [port: 6969, region: :na]}]
  defp start_server(:eu), do: [{Net.Server, [port: 7979, region: :eu]}]
  defp start_server(:as), do: [{Net.Server, [port: 8989, region: :as]}]
  defp start_server(_), do: []
end
