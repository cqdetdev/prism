defmodule OomfTest do
  use ExUnit.Case
  doctest Oomf

  test "greets the world" do
    assert Oomf.hello() == :world
  end
end
