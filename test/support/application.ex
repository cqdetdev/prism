defmodule Prism.TestApplication do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Prism.start(:normal, [])
  end
end
