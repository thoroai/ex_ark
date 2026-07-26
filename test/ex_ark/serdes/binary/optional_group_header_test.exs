defmodule ExArk.Serdes.Binary.OptionalGroupHeaderTest do
  use ExUnit.Case, async: true

  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.OptionalGroupHeader

  test "returns an error for a truncated optional group header" do
    stream = %InputStream{bytes: <<0xE0, 1, 2, 3, 4>>}

    assert {:error, :bad_optional_group_header} = OptionalGroupHeader.read(stream)
  end
end
