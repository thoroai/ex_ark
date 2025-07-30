defmodule ExArk.Serdes.Json.Fields.EnumTest do
  use ExUnit.Case, async: true
  alias ExArk

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/enums.ir")
    {:ok, %{registry: registry}}
  end

  describe "raw enum serialization and deserialization" do
    test "value roundtrip", %{registry: registry} do
      data = %{field: :THREE}
      type = "ex_ark::test::ValueObject"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end

    test "bitmask roundtrip", %{registry: registry} do
      data = %{field: [:BIT_0, :BIT_2, :BIT_4, :BIT_6]}
      type = "ex_ark::test::BitmaskObject"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data

      data = %{field: [:BIT_1, :BIT_3, :BIT_5, :BIT_7]}
      type = "ex_ark::test::BitmaskObject"

      {:ok, serialized} = ExArk.write_object_to_json(registry, type, data)
      {:ok, deserialized} = ExArk.read_object_from_json(registry, type, serialized)

      assert deserialized == data
    end
  end
end
