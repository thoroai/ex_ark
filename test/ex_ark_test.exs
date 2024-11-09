defmodule ExArkTest do
  use ExUnit.Case
  doctest ExArk

  test "greets the world" do
    assert ExArk.hello() == :world
  end
end
