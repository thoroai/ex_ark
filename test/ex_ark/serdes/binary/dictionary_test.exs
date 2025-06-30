defmodule ExArk.Serdes.Binary.Fields.DictionaryTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/dictionaries.ir")
    {:ok, %{registry: registry}}
  end

  describe "dictionary raw serialization and deserialization" do
    test "roundtrip", %{registry: registry} do
      data = %{string_to_int_dictionary: %{"one" => 1, "two" => 2, "three" => 3}}
      type = "ex_ark::test::StringToIntDictionary"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end

    test "default roundtrip", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::StringToIntDictionary"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == %{string_to_int_dictionary: %{}}
    end

    test "nested roundtrip", %{registry: registry} do
      data = %{
        nested_dictionary: %{
          "red" => %{"one" => 1, "two" => 2},
          "green" => %{"three" => 3, "four" => 4},
          "blue" => %{"five" => 5, "six" => 6, "seven" => 7}
        }
      }

      type = "ex_ark::test::NestedDictionary"

      {:ok, serialized} = ExArk.write_object_to_bytes(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_bytes(registry, type, serialized)

      assert deserialized == data
    end
  end
end
