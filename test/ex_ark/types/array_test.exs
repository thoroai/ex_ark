defmodule ExArk.Serdes.ArrayTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/arrays.ir")
    {:ok, %{registry: registry}}
  end

  describe "basic array serialization and deserialization" do
    test "array of integers", %{registry: registry} do
      data = %{int_array: [1, 2, 3]}
      type = "ex_ark::test::IntArray"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "default array of integers", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::IntArray"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == %{int_array: [0, 0, 0]}
    end

    test "missing optional array of integers", %{registry: registry} do
      data = %{required_preamble_array: [1, 2, 3], required_postamble_array: [4, 5, 6]}
      type = "ex_ark::test::OptionalArray"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "present optional array of strings", %{registry: registry} do
      data = %{
        required_preamble_array: [1, 2, 3],
        optional_array: ["foo", "bar", "qux"],
        required_postamble_array: [4, 5, 6]
      }

      type = "ex_ark::test::OptionalArray"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "array of array of strings", %{registry: registry} do
      data = %{nested_string_array: [["a", "b", "c"], ["one", "two", "three"], ["foo", "bar", "qux"]]}
      type = "ex_ark::test::NestedStringArray"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end
  end
end
