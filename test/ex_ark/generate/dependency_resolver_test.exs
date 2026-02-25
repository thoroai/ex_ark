defmodule ExArk.Generate.DependencyResolverTest do
  use ExUnit.Case, async: true

  alias ExArk.Generate.DependencyResolver
  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Field
  alias ExArk.Ir.Group
  alias ExArk.Ir.Schema
  alias ExArk.Ir.Variant
  alias ExArk.Registry

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp field(name, type, extra \\ %{}) do
    struct(Field, Map.merge(%{name: name, type: type, attributes: [], variant_types: []}, extra))
  end

  defp object_field(name, object_type) do
    field(name, "object", %{object_type: object_type})
  end

  defp enum_field(name, object_type) do
    field(name, "enum", %{object_type: object_type})
  end

  defp variant_field(name, variants) do
    vtypes = Enum.map(variants, fn {idx, ot} -> %Variant{index: idx, object_type: ot} end)
    field(name, "variant", %{variant_types: vtypes})
  end

  defp arraylist_field(name, elem_type_string) do
    field(name, "arraylist", %{ctr_value_type: field(nil, elem_type_string)})
  end

  defp arraylist_object_field(name, object_type) do
    elem = object_field(nil, object_type)
    field(name, "arraylist", %{ctr_value_type: elem})
  end

  defp dictionary_field(name, key_type, val_type) do
    field(name, "dictionary", %{
      ctr_key_type: field(nil, key_type),
      ctr_value_type: field(nil, val_type)
    })
  end

  defp simple_schema(name, fields, namespace \\ nil) do
    %Schema{name: name, object_namespace: namespace, fields: fields, groups: [], attributes: []}
  end

  defp schema_with_groups(name, fields, groups, namespace \\ nil) do
    group_list =
      Enum.with_index(groups)
      |> Enum.map(fn {fields, idx} -> %Group{identifier: idx, fields: fields} end)

    %Schema{
      name: name,
      object_namespace: namespace,
      fields: fields,
      groups: group_list,
      attributes: []
    }
  end

  defp simple_enum(name, namespace \\ nil) do
    %ArkEnum{
      name: name,
      object_namespace: namespace,
      enum_class: :uint8,
      enum_type: :value,
      values: %{A: 0, B: 1}
    }
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "resolve/2 — simple cases" do
    test "single schema with only primitive fields" do
      schema = simple_schema("Foo", [field("x", "string"), field("y", "uint32")])
      registry = %Registry{schemas: %{"Foo" => schema}, enums: %{}}

      {schemas, enums} = DependencyResolver.resolve(registry, ["Foo"])

      assert schemas == [schema]
      assert enums == []
    end

    test "multiple top-level schemas, no shared deps" do
      a = simple_schema("A", [field("x", "string")])
      b = simple_schema("B", [field("y", "uint32")])
      registry = %Registry{schemas: %{"A" => a, "B" => b}, enums: %{}}

      {schemas, enums} = DependencyResolver.resolve(registry, ["A", "B"])

      assert Enum.sort_by(schemas, & &1.name) == Enum.sort_by([a, b], & &1.name)
      assert enums == []
    end

    test "empty top-level list returns empty" do
      registry = %Registry{schemas: %{}, enums: %{}}
      assert DependencyResolver.resolve(registry, []) == {[], []}
    end
  end

  describe "resolve/2 — object field dependencies" do
    test "schema with direct object dep includes dep first" do
      child = simple_schema("Child", [field("v", "int32")])
      parent = simple_schema("Parent", [object_field("child", "Child")])
      registry = %Registry{schemas: %{"Child" => child, "Parent" => parent}, enums: %{}}

      {schemas, _enums} = DependencyResolver.resolve(registry, ["Parent"])

      assert schemas == [child, parent]
    end

    test "transitive deps: A → B → C" do
      c = simple_schema("C", [field("v", "int32")])
      b = simple_schema("B", [object_field("c", "C")])
      a = simple_schema("A", [object_field("b", "B")])

      registry = %Registry{
        schemas: %{"A" => a, "B" => b, "C" => c},
        enums: %{}
      }

      {schemas, _enums} = DependencyResolver.resolve(registry, ["A"])

      assert schemas == [c, b, a]
    end

    test "shared dep is included only once" do
      shared = simple_schema("Shared", [field("v", "int32")])
      a = simple_schema("A", [object_field("s", "Shared")])
      b = simple_schema("B", [object_field("s", "Shared")])
      root = simple_schema("Root", [object_field("a", "A"), object_field("b", "B")])

      registry = %Registry{
        schemas: %{"Shared" => shared, "A" => a, "B" => b, "Root" => root},
        enums: %{}
      }

      {schemas, _enums} = DependencyResolver.resolve(registry, ["Root"])

      assert length(schemas) == 4
      assert Enum.count(schemas, &(&1.name == "Shared")) == 1
    end
  end

  describe "resolve/2 — variant field dependencies" do
    test "variant field includes all variant types" do
      v1 = simple_schema("V1", [field("x", "string")])
      v2 = simple_schema("V2", [field("y", "uint32")])
      parent = simple_schema("Parent", [variant_field("data", [{1, "V1"}, {2, "V2"}])])

      registry = %Registry{schemas: %{"V1" => v1, "V2" => v2, "Parent" => parent}, enums: %{}}

      {schemas, _enums} = DependencyResolver.resolve(registry, ["Parent"])

      assert length(schemas) == 3
      assert Enum.any?(schemas, &(&1.name == "V1"))
      assert Enum.any?(schemas, &(&1.name == "V2"))
      assert Enum.any?(schemas, &(&1.name == "Parent"))
    end
  end

  describe "resolve/2 — enum field dependencies" do
    test "enum field collects the enum" do
      e = simple_enum("Status")
      schema = simple_schema("Foo", [enum_field("status", "Status")])
      registry = %Registry{schemas: %{"Foo" => schema}, enums: %{"Status" => e}}

      {_schemas, enums} = DependencyResolver.resolve(registry, ["Foo"])

      assert enums == [e]
    end

    test "same enum referenced twice is included once" do
      e = simple_enum("Status")
      child = simple_schema("Child", [enum_field("s", "Status")])
      parent = simple_schema("Parent", [object_field("c", "Child"), enum_field("s", "Status")])

      registry = %Registry{
        schemas: %{"Child" => child, "Parent" => parent},
        enums: %{"Status" => e}
      }

      {_schemas, enums} = DependencyResolver.resolve(registry, ["Parent"])

      assert enums == [e]
    end
  end

  describe "resolve/2 — container field dependencies" do
    test "arraylist of primitives has no schema deps" do
      schema = simple_schema("Foo", [arraylist_field("tags", "string")])
      registry = %Registry{schemas: %{"Foo" => schema}, enums: %{}}

      {schemas, enums} = DependencyResolver.resolve(registry, ["Foo"])

      assert schemas == [schema]
      assert enums == []
    end

    test "arraylist of objects includes element schema" do
      elem = simple_schema("Item", [field("v", "int32")])
      parent = simple_schema("Container", [arraylist_object_field("items", "Item")])

      registry = %Registry{
        schemas: %{"Item" => elem, "Container" => parent},
        enums: %{}
      }

      {schemas, _enums} = DependencyResolver.resolve(registry, ["Container"])

      assert schemas == [elem, parent]
    end

    test "dictionary of primitives has no schema deps" do
      schema = simple_schema("Foo", [dictionary_field("m", "string", "int32")])
      registry = %Registry{schemas: %{"Foo" => schema}, enums: %{}}

      {schemas, _} = DependencyResolver.resolve(registry, ["Foo"])

      assert schemas == [schema]
    end
  end

  describe "resolve/2 — group fields" do
    test "group fields are walked for deps" do
      dep = simple_schema("Dep", [field("v", "int32")])

      schema =
        schema_with_groups(
          "WithGroup",
          [field("base", "string")],
          [[object_field("dep", "Dep")]]
        )

      registry = %Registry{schemas: %{"Dep" => dep, "WithGroup" => schema}, enums: %{}}

      {schemas, _} = DependencyResolver.resolve(registry, ["WithGroup"])

      assert schemas == [dep, schema]
    end
  end

  describe "resolve/2 — error cases" do
    test "raises when top-level schema is missing" do
      registry = %Registry{schemas: %{}, enums: %{}}

      assert_raise ArgumentError, ~r/schema "Missing".*not present in the registry/, fn ->
        DependencyResolver.resolve(registry, ["Missing"])
      end
    end

    test "raises when referenced object schema is missing" do
      parent = simple_schema("Parent", [object_field("child", "Missing")])
      registry = %Registry{schemas: %{"Parent" => parent}, enums: %{}}

      assert_raise ArgumentError, ~r/schema "Missing".*not present in the registry/, fn ->
        DependencyResolver.resolve(registry, ["Parent"])
      end
    end

    test "raises when referenced variant schema is missing" do
      parent = simple_schema("Parent", [variant_field("data", [{1, "MissingVariant"}])])
      registry = %Registry{schemas: %{"Parent" => parent}, enums: %{}}

      assert_raise ArgumentError, ~r/schema "MissingVariant".*not present in the registry/, fn ->
        DependencyResolver.resolve(registry, ["Parent"])
      end
    end

    test "raises when referenced enum is missing" do
      schema = simple_schema("Foo", [enum_field("status", "MissingEnum")])
      registry = %Registry{schemas: %{"Foo" => schema}, enums: %{}}

      assert_raise ArgumentError, ~r/enum "MissingEnum".*not present in the registry/, fn ->
        DependencyResolver.resolve(registry, ["Foo"])
      end
    end

    test "error message includes the field name and parent schema name" do
      parent = simple_schema("ParentSchema", [object_field("broken_field", "Missing")])
      registry = %Registry{schemas: %{"ParentSchema" => parent}, enums: %{}}

      assert_raise ArgumentError,
                   ~r/field "broken_field" in schema ParentSchema/,
                   fn ->
                     DependencyResolver.resolve(registry, ["ParentSchema"])
                   end
    end
  end
end
