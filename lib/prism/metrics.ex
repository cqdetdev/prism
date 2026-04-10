defmodule Prism.Metrics do
  @moduledoc false

  def snapshot do
    case Process.whereis(Prism.Metrics.Reporter) do
      nil -> {:error, :not_running}
      _pid -> Prism.Metrics.Reporter.snapshot()
    end
  end
end
