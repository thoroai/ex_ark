defmodule ExArk.Serdes.DictionaryTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/dictionaries.ir")
    {:ok, %{registry: registry}}
  end

  describe "basic dictionary serialization and deserialization" do
    test "dictionary of strings to integers", %{registry: registry} do
      data = %{string_to_int_dictionary: %{"one" => 1, "two" => 2, "three" => 3}}
      type = "ex_ark::test::StringToIntDictionary"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "default dictionary of strings to integers", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::StringToIntDictionary"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == %{string_to_int_dictionary: %{}}
    end
  end
end
