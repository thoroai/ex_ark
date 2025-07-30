defmodule ExArk.Serdes.JsonTest do
  use ExUnit.Case, async: true
  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Fields.Primitives

  describe "deserialization" do
    test "sanitize/1 fixes non-compliant JSON" do
      jsonstr = "{\"field_a\": Infinity, \"field_b\": -Infinity, \"field_c\": NaN}"
      json = jsonstr |> Json.sanitize() |> JSON.decode!()

      assert json["field_a"] == Primitives.inf()
      assert json["field_b"] == -Primitives.inf()
      assert json["field_c"] == nil
    end
  end
end
