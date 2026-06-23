defmodule ExArk.RegistryTest do
  use ExUnit.Case, async: true

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Field
  alias ExArk.Ir.Group
  alias ExArk.Ir.Schema
  alias ExArk.Ir.Variant
  alias ExArk.Registry

  defp field(name, type, extra \\ %{}) do
    struct(Field, Map.merge(%{name: name, type: type, attributes: [], variant_types: []}, extra))
  end

  defp object_field(name, object_type) do
    field(name, "object", %{object_type: object_type})
  end

  defp enum_field(name, object_type) do
    field(name, "enum", %{object_type: object_type})
  end

  defp arraylist_object_field(name, object_type) do
    field(name, "arraylist", %{ctr_value_type: object_field(nil, object_type)})
  end

  defp variant_field(name, variants) do
    vtypes = Enum.map(variants, fn {idx, ot} -> %Variant{index: idx, object_type: ot} end)
    field(name, "variant", %{variant_types: vtypes})
  end

  defp schema(name, fields, groups \\ []) do
    %Schema{name: name, object_namespace: nil, fields: fields, groups: groups, attributes: []}
  end

  defp group(identifier, fields) do
    %Group{identifier: identifier, fields: fields}
  end

  defp enum(name) do
    %ArkEnum{
      name: name,
      object_namespace: nil,
      enum_class: :uint8,
      enum_type: :value,
      values: %{A: 0, B: 1}
    }
  end

  test "build_from keeps only transitive schema and enum dependencies" do
    child = schema("Child", [field("value", "string")])
    parent = schema("Parent", [object_field("child", "Child")])

    root =
      schema(
        "Root",
        [object_field("parent", "Parent"), enum_field("status", "Status")],
        [group(1, [arraylist_object_field("children", "Child"), variant_field("choice", [{1, "Child"}])])]
      )

    registry = %Registry{
      schemas: %{
        "Root" => root,
        "Parent" => parent,
        "Child" => child,
        "Unused" => schema("Unused", [field("x", "uint32")])
      },
      enums: %{
        "Status" => enum("Status"),
        "UnusedEnum" => enum("UnusedEnum")
      }
    }

    assert {:ok, pruned} = Registry.build_from(registry, root)

    assert Map.keys(pruned.schemas) |> Enum.sort() == ["Child", "Parent", "Root"]
    assert Map.keys(pruned.enums) == ["Status"]
    assert pruned.schemas["Root"] == root
    assert pruned.schemas["Parent"] == parent
    assert pruned.schemas["Child"] == child
  end

  test "build_from returns an error when a dependency is missing" do
    root = schema("Root", [object_field("child", "Child")])

    registry = %Registry{
      schemas: %{
        "Root" => root
      },
      enums: %{}
    }

    assert {:error, message} = Registry.build_from(registry, root)
    assert message == "missing schema dependency: \"Child\""
  end
end
