defmodule Prism.Health do
  @moduledoc false

  def snapshot do
    %{
      status: overall_status(),
      region: Prism.current_region(),
      udp: component_status(&udp_started?/0, Application.get_env(:prism, :start_udp, true)),
      database:
        component_status(&database_started?/0, Application.get_env(:prism, :start_database, true)),
      redis: component_status(&redis_started?/0, Application.get_env(:prism, :start_redix, true)),
      cluster: %{
        enabled: Application.get_env(:prism, :start_cluster, true),
        connected_nodes: Node.list()
      },
      services: service_list(),
      metrics: Prism.Metrics.snapshot()
    }
  end

  defp overall_status do
    cond do
      Application.get_env(:prism, :start_udp, true) and not udp_started?() -> :degraded
      Application.get_env(:prism, :start_database, true) and not database_started?() -> :degraded
      Application.get_env(:prism, :start_redix, true) and not redis_started?() -> :degraded
      true -> :ok
    end
  end

  defp component_status(check_fun, true), do: if(check_fun.(), do: :ok, else: :down)
  defp component_status(_check_fun, false), do: :disabled

  defp udp_started? do
    case Prism.current_region() do
      nil -> false
      region -> :global.whereis_name(region) != :undefined
    end
  end

  defp database_started? do
    Process.whereis(Data.Repo) != nil
  end

  defp redis_started? do
    Process.whereis(:redix) != nil
  end

  defp service_list do
    if Process.whereis(Net.Service.Registry) do
      Net.Service.Registry.all()
    else
      []
    end
  end
end
