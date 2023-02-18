defmodule SentinelTest do
  use ExUnit.Case
  doctest Sentinel

  test "greets the world" do
    assert Sentinel.hello() == :world
  end
end
