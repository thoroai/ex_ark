defmodule ExArk.Serdes.VariantTest do
  use ExUnit.Case, async: true
  alias ExArk
  alias ExArk.Types.Object

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/variants.ir")
    {:ok, %{registry: registry}}
  end

  describe "raw variant serialization and deserialization" do
    test "roundtrip", %{registry: registry} do
      data = %{variant_field: %{field_b: %{"key1" => 42, "key2" => 74}} |> Object.add_type("ex_ark::test::ObjectB")}
      type = "ex_ark::test::Variant"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "default roundtrip", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::Variant"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == %{variant_field: %{field_a: 0} |> Object.add_type("ex_ark::test::ObjectA")}
    end
  end
end
