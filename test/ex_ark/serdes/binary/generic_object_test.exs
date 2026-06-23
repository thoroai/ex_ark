defmodule ExArk.Serdes.Binary.GenericObjectTest do
  use ExUnit.Case, async: true

  alias ExArk.Serdes.Binary.FileTrailer
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/objects.ir")
    {:ok, %{registry: registry}}
  end

  test "generic object roundtrips with a minimal embedded registry", %{registry: registry} do
    type = "ex_ark::test::ObjectWithOptionalGroup"

    data = %{
      id: "test-id",
      value: 42,
      group_field_1: "group-value",
      group_field_2: 99
    }

    {:ok, bytes} = ExArk.write_generic_object_to_bytes(registry, type, data)
    {:ok, payload} = ExArk.read_generic_object_from_bytes(bytes)

    assert payload.object.id == "test-id"
    assert payload.object.group_field_1 == "group-value"
    assert payload.object.group_field_2 == 99
    refute Map.has_key?(payload.object, :__ark_schema)

    {:ok, {_, trailer}} = FileTrailer.read(bytes)
    {:ok, %Result{stream: stream, reified: ^type}} = Primitives.read(:string, %InputStream{bytes: trailer})
    {:ok, %Result{reified: registry_json}} = Primitives.read(:string, stream)
    {:ok, registry_json} = JSON.decode(registry_json)

    refute contains_key?(registry_json, "comments")
    refute contains_key?(registry_json, "source_location")
    refute contains_key?(registry_json["schemas"], "comments")
    refute contains_key?(registry_json["schemas"], "source_location")
  end

  defp contains_key?(%{} = map, key) do
    Map.has_key?(map, key) or Enum.any?(map, fn {_k, value} -> contains_key?(value, key) end)
  end

  defp contains_key?([head | tail], key), do: contains_key?(head, key) or contains_key?(tail, key)
  defp contains_key?([], _key), do: false
  defp contains_key?(_other, _key), do: false
end
