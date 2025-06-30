defmodule ExArk.Serdes.Json.Fields.ArrayTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/arrays.ir")
    {:ok, %{registry: registry}}
  end

  describe "array raw serialization and deserialization" do
    test "roundtrip", %{registry: registry} do
      data = %{int_array: [1, 2, 3]}
      type = "ex_ark::test::IntArray"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "default roundtrip", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::IntArray"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == %{int_array: [0, 0, 0]}
    end

    test "missing optional", %{registry: registry} do
      data = %{required_preamble_array: [1, 2, 3], required_postamble_array: [4, 5, 6]}
      type = "ex_ark::test::OptionalArray"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "present optional", %{registry: registry} do
      data = %{
        required_preamble_array: [1, 2, 3],
        optional_array: ["foo", "bar", "qux"],
        required_postamble_array: [4, 5, 6]
      }

      type = "ex_ark::test::OptionalArray"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "nested roundtrip", %{registry: registry} do
      data = %{nested_string_array: [["a", "b", "c"], ["one", "two", "three"], ["foo", "bar", "qux"]]}
      type = "ex_ark::test::NestedStringArray"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end
  end
end
