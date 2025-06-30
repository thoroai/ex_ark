defmodule ExArk.Serdes.ArrayListTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/array_lists.ir")
    {:ok, %{registry: registry}}
  end

  describe "basic array list serialization and deserialization" do
    test "array list of integers", %{registry: registry} do
      data = %{int_arraylist: [1, 2, 3]}
      type = "ex_ark::test::IntArrayList"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "default array list of integers", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::IntArrayList"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == %{int_arraylist: []}
    end
  end
end
