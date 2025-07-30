defmodule ExArk.Serdes.Json.ObjectTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/objects.ir")
    {:ok, %{registry: registry}}
  end

  describe "raw object serialization and deserialization" do
    test "groups", %{registry: registry} do
      data = %{field: 1, field_0: 10, field_1: 11, field_4: 20, field_5: 21}
      type = "ex_ark::test::GroupsObject"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "final roundtrip", %{registry: registry} do
      data = %{field: %{"key1" => 42, "key2" => 74}}
      type_final = "ex_ark::test::FinalObject"

      {:ok, serialized_final} = ExArk.write_object_to_json(registry, type_final, data)
      {:ok, deserialized_final} = ExArk.read_object_from_json(registry, type_final, serialized_final)

      assert deserialized_final == data

      type = "ex_ark::test::Object"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
      assert serialized == serialized_final
    end
  end
end
