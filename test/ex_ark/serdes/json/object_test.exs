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

    test "optional groups - deserializing old data without group fields", %{registry: registry} do
      # Simulate old schema data that doesn't have the group fields
      old_json = JSON.encode!(%{"id" => "test-id", "value" => 42})
      type = "ex_ark::test::ObjectWithOptionalGroup"

      # Should succeed - missing group should be treated as optional
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, old_json)

      # Should have the regular fields but not the group fields
      assert deserialized.id == "test-id"
      assert deserialized.value == 42
      assert Map.has_key?(deserialized, :group_field_1) == false
      assert Map.has_key?(deserialized, :group_field_2) == false
    end

    test "optional groups - deserializing new data with group fields", %{registry: registry} do
      # New schema data that includes the group fields
      new_json =
        JSON.encode!(%{
          "id" => "test-id",
          "value" => 42,
          "group_field_1" => "group-value",
          "group_field_2" => 99
        })

      type = "ex_ark::test::ObjectWithOptionalGroup"

      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, new_json)

      # Should have all fields
      assert deserialized.id == "test-id"
      assert deserialized.value == 42
      assert deserialized.group_field_1 == "group-value"
      assert deserialized.group_field_2 == 99
    end

    test "optional groups - roundtrip with group fields", %{registry: registry} do
      data = %{
        id: "test-id",
        value: 42,
        group_field_1: "group-value",
        group_field_2: 99
      }

      type = "ex_ark::test::ObjectWithOptionalGroup"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "optional fields - missing optional fields", %{registry: registry} do
      # JSON with only required fields, no optional fields
      json = JSON.encode!(%{"required_field" => "test", "another_required_field" => 42})
      type = "ex_ark::test::ObjectWithOptionalFields"

      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, json)

      # Should have required fields but not optional fields
      assert deserialized.required_field == "test"
      assert deserialized.another_required_field == 42
      assert Map.has_key?(deserialized, :optional_string) == false
      assert Map.has_key?(deserialized, :optional_int) == false
    end

    test "optional fields - present optional fields", %{registry: registry} do
      json =
        JSON.encode!(%{
          "required_field" => "test",
          "optional_string" => "optional-value",
          "optional_int" => 99,
          "another_required_field" => 42
        })

      type = "ex_ark::test::ObjectWithOptionalFields"

      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, json)

      # Should have all fields
      assert deserialized.required_field == "test"
      assert deserialized.optional_string == "optional-value"
      assert deserialized.optional_int == 99
      assert deserialized.another_required_field == 42
    end

    test "optional fields - partial optional fields", %{registry: registry} do
      # Only one of the optional fields is present
      json =
        JSON.encode!(%{
          "required_field" => "test",
          "optional_string" => "optional-value",
          "another_required_field" => 42
        })

      type = "ex_ark::test::ObjectWithOptionalFields"

      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, json)

      # Should have required fields and one optional field
      assert deserialized.required_field == "test"
      assert deserialized.optional_string == "optional-value"
      assert Map.has_key?(deserialized, :optional_int) == false
      assert deserialized.another_required_field == 42
    end

    test "optional fields - roundtrip with optional fields", %{registry: registry} do
      data = %{
        required_field: "test",
        optional_string: "optional-value",
        optional_int: 99,
        another_required_field: 42
      }

      type = "ex_ark::test::ObjectWithOptionalFields"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "optional fields - roundtrip without optional fields", %{registry: registry} do
      data = %{
        required_field: "test",
        another_required_field: 42
      }

      type = "ex_ark::test::ObjectWithOptionalFields"

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
