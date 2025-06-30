defmodule ExArk.Serdes.Json.Fields.VariantTest do
  use ExUnit.Case, async: true
  alias ExArk
  alias ExArk.Types

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/variants.ir")
    {:ok, %{registry: registry}}
  end

  describe "raw variant serialization and deserialization" do
    test "roundtrip", %{registry: registry} do
      data = %{variant_field: %{field_b: %{"key1" => 42, "key2" => 74}} |> Types.add_type("ex_ark::test::ObjectB")}
      type = "ex_ark::test::Variant"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "default roundtrip", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::Variant"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == %{variant_field: %{field_a: 0} |> Types.add_type("ex_ark::test::ObjectA")}
    end
  end
end
