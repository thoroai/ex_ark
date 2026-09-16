defmodule ExArk.Serdes.Json.Fields.DictionaryTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/dictionaries.ir")
    {:ok, %{registry: registry}}
  end

  describe "dictionary raw serialization and deserialization" do
    test "roundtrip", %{registry: registry} do
      data = %{string_to_int_dictionary: %{"one" => 1, "two" => 2, "three" => 3}}
      type = "ex_ark::test::StringToIntDictionary"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert JSON.decode!(serialized) == %{
               "string_to_int_dictionary" => %{"one" => 1, "two" => 2, "three" => 3}
             }

      assert deserialized == data
    end

    test "reads the canonical C++ string-keyed representation", %{registry: registry} do
      type = "ex_ark::test::StringToIntDictionary"
      json = ~s({"string_to_int_dictionary":{"one":1,"two":2}})

      assert {:ok, %{string_to_int_dictionary: %{"one" => 1, "two" => 2}}} =
               ExArk.read_object_from_json(registry, type, json)
    end

    test "reads the legacy ex_ark pair representation", %{registry: registry} do
      type = "ex_ark::test::StringToIntDictionary"
      json = ~s({"string_to_int_dictionary":[["one",1],["two",2]]})

      assert {:ok, %{string_to_int_dictionary: %{"one" => 1, "two" => 2}}} =
               ExArk.read_object_from_json(registry, type, json)
    end

    test "default roundtrip", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::StringToIntDictionary"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert JSON.decode!(serialized) == %{"string_to_int_dictionary" => %{}}
      assert deserialized == %{string_to_int_dictionary: %{}}
    end

    test "continues to read legacy null as an empty dictionary", %{registry: registry} do
      type = "ex_ark::test::StringToIntDictionary"

      assert {:ok, %{string_to_int_dictionary: %{}}} =
               ExArk.read_object_from_json(registry, type, ~s({"string_to_int_dictionary":null}))
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

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert JSON.decode!(serialized)["nested_dictionary"]["red"] == %{"one" => 1, "two" => 2}
      assert deserialized == data
    end

    test "integer keys retain the array-of-pairs representation", %{registry: registry} do
      data = %{integer_key_dictionary: %{1 => "one", 2 => "two"}}
      type = "ex_ark::test::IntegerKeyDictionary"

      assert {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      assert %{"integer_key_dictionary" => pairs} = JSON.decode!(serialized)
      assert Enum.sort(pairs) == [[1, "one"], [2, "two"]]
      assert {:ok, ^data} = ExArk.read_object_from_json(registry, type, serialized)
    end

    test "an empty non-string-keyed dictionary is an array", %{registry: registry} do
      type = "ex_ark::test::IntegerKeyDictionary"

      assert {:ok, serialized} = ExArk.write_object_to_json(registry, type, %{})
      assert JSON.decode!(serialized) == %{"integer_key_dictionary" => []}
    end

    test "GUID keys use the object representation", %{registry: registry} do
      guid = "12345678-1234-1234-1234-123456789abc"
      data = %{guid_key_dictionary: %{guid => 7}}
      type = "ex_ark::test::GuidKeyDictionary"

      assert {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      assert JSON.decode!(serialized) == %{"guid_key_dictionary" => %{guid => 7}}
      assert {:ok, ^data} = ExArk.read_object_from_json(registry, type, serialized)
    end

    test "enum keys use their names in the object representation", %{registry: registry} do
      data = %{enum_key_dictionary: %{ONE: 1, TWO: 2}}
      type = "ex_ark::test::EnumKeyDictionary"

      assert {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      assert JSON.decode!(serialized) == %{"enum_key_dictionary" => %{"ONE" => 1, "TWO" => 2}}
      assert {:ok, ^data} = ExArk.read_object_from_json(registry, type, serialized)
    end

    test "object values use the object representation recursively", %{registry: registry} do
      data = %{
        object_dictionary: %{
          "first" => %{label: "one", count: 1},
          "second" => %{label: "two", count: 2}
        }
      }

      type = "ex_ark::test::StringToObjectDictionary"

      assert {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)

      assert JSON.decode!(serialized) == %{
               "object_dictionary" => %{
                 "first" => %{"label" => "one", "count" => 1},
                 "second" => %{"label" => "two", "count" => 2}
               }
             }

      assert {:ok, ^data} = ExArk.read_object_from_json(registry, type, serialized)
    end

    test "malformed pair entries return an error rather than raising", %{registry: registry} do
      type = "ex_ark::test::IntegerKeyDictionary"
      json = ~s({"integer_key_dictionary":[[1,"one"],[2]]})

      capture_log(fn ->
        assert {:error, :deserialization_error} = ExArk.read_object_from_json(registry, type, json)
      end)
    end
  end
end
