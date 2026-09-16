defmodule ExArk.Serdes.Json.Fields.DictionaryTest do
  use ExUnit.Case, async: true
  alias ExArk

  @product_config_type "ex_ark::test::ProductConfig"

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

      assert deserialized == data
    end

    test "default roundtrip", %{registry: registry} do
      data = %{}
      type = "ex_ark::test::StringToIntDictionary"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

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

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end
  end

  describe "dictionary wire format" do
    test "writes a string-keyed dictionary as a json object", %{registry: registry} do
      {:ok, serialized} = ExArk.write_object_to_json(registry, @product_config_type, product_config())

      assert Jason.decode!(serialized) == json_product_config()
    end

    test "reads a string-keyed dictionary written as a json object", %{registry: registry} do
      serialized = Jason.encode!(json_product_config())

      assert {:ok, data} = ExArk.read_object_from_json(registry, @product_config_type, serialized)
      assert data == product_config()
    end

    test "writes a guid-keyed dictionary as a json object", %{registry: registry} do
      data = %{dictionary: %{"3f2504e0-4f89-11d3-9a0c-0305e82c3301" => 1}}

      {:ok, serialized} = ExArk.write_object_to_json(registry, "ex_ark::test::GuidToIntDictionary", data)

      assert Jason.decode!(serialized) == %{"dictionary" => %{"3f2504e0-4f89-11d3-9a0c-0305e82c3301" => 1}}
    end

    test "reads a guid-keyed dictionary written as a json object", %{registry: registry} do
      serialized = ~s({"dictionary":{"3f2504e0-4f89-11d3-9a0c-0305e82c3301":1}})

      assert {:ok, data} = ExArk.read_object_from_json(registry, "ex_ark::test::GuidToIntDictionary", serialized)
      assert data == %{dictionary: %{"3f2504e0-4f89-11d3-9a0c-0305e82c3301" => 1}}
    end

    test "writes an enum-keyed dictionary as a json object keyed by the enum name", %{registry: registry} do
      data = %{dictionary: %{Red: 1, Green: 2}}

      {:ok, serialized} = ExArk.write_object_to_json(registry, "ex_ark::test::EnumToIntDictionary", data)

      assert Jason.decode!(serialized) == %{"dictionary" => %{"Red" => 1, "Green" => 2}}
    end

    test "reads an enum-keyed dictionary written as a json object", %{registry: registry} do
      serialized = ~s({"dictionary":{"Red":1,"Green":2}})

      assert {:ok, data} = ExArk.read_object_from_json(registry, "ex_ark::test::EnumToIntDictionary", serialized)
      assert data == %{dictionary: %{Red: 1, Green: 2}}
    end

    test "writes an int-keyed dictionary as an array of pairs", %{registry: registry} do
      data = %{dictionary: %{1 => 10, 2 => 20}}

      {:ok, serialized} = ExArk.write_object_to_json(registry, "ex_ark::test::IntToIntDictionary", data)

      assert Jason.decode!(serialized) == %{"dictionary" => [[1, 10], [2, 20]]}
    end

    test "reads an int-keyed dictionary written as an array of pairs", %{registry: registry} do
      serialized = ~s({"dictionary":[[1,10],[2,20]]})

      assert {:ok, data} = ExArk.read_object_from_json(registry, "ex_ark::test::IntToIntDictionary", serialized)
      assert data == %{dictionary: %{1 => 10, 2 => 20}}
    end

    test "writes null for an empty dictionary", %{registry: registry} do
      {:ok, serialized} = ExArk.write_object_to_json(registry, @product_config_type, %{categories: %{}})

      assert Jason.decode!(serialized) == %{"categories" => nil}
    end

    test "reads null as an empty dictionary", %{registry: registry} do
      assert {:ok, data} = ExArk.read_object_from_json(registry, @product_config_type, ~s({"categories":null}))
      assert data == %{categories: %{}}
    end
  end

  defp product_config do
    %{
      categories: %{
        "log" => %{
          upload_immediate: true,
          priority: 0,
          max_space_in_blocks: 131_072,
          min_free_space_in_blocks: 16_384,
          min_age_in_days: 1
        }
      }
    }
  end

  defp json_product_config do
    %{
      "categories" => %{
        "log" => %{
          "upload_immediate" => true,
          "priority" => 0,
          "max_space_in_blocks" => 131_072,
          "min_free_space_in_blocks" => 16_384,
          "min_age_in_days" => 1
        }
      }
    }
  end
end
