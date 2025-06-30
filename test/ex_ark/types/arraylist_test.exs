defmodule ExArk.Serdes.ArrayListTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/array_lists.ir")
    {:ok, %{registry: registry}}
  end

  describe "array list raw serialization and deserialization" do
    test "roundtrip", %{registry: registry} do
      data = %{int_arraylist: [1, 2, 3]}
      type = "ex_ark::test::IntArrayList"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "default roundtrip", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::IntArrayList"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == %{int_arraylist: []}
    end

    test "nested roundtrip", %{registry: registry} do
      data = %{nested_string_arraylist: [["a", "b", "c"], ["one", "two"], ["red", "blue", "green"]]}
      type = "ex_ark::test::NestedStringArrayList"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end
  end
end
