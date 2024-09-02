defmodule AtprotoTest do
  use ExUnit.Case
  doctest Atproto

  test "greets the world" do
    assert Atproto.hello() == :world
  end
end
