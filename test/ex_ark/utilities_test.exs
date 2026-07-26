defmodule ExArk.UtilitiesTest do
  use ExUnit.Case, async: true

  alias ExArk.Utilities

  test "does not depend on Mix at runtime" do
    assert {Utilities, beam, _filename} = :code.get_object_code(Utilities)
    assert {:ok, {Utilities, [imports: imports]}} = :beam_lib.chunks(beam, [:imports])

    refute {Mix, :env, 0} in imports
  end
end
