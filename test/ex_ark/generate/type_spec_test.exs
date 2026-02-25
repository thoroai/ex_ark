defmodule ExArk.Generate.TypeSpecTest do
  use ExUnit.Case, async: true

  alias ExArk.Generate.TypeSpec
  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Ir.Variant
  alias ExArk.Registry

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp field(type, extra \\ %{}) do
    struct(Field, Map.merge(%{name: "f", type: type, attributes: [], variant_types: []}, extra))
  end

  defp empty_registry, do: %Registry{schemas: %{}, enums: %{}}

  defp registry_with_schema(ark_name) do
    {name, ns} =
      case String.split(ark_name, "::") do
        [n] -> {n, nil}
        parts -> {List.last(parts), parts |> Enum.drop(-1) |> Enum.join("::")}
      end

    schema = %Schema{name: name, object_namespace: ns, fields: [], groups: [], attributes: []}
    %Registry{schemas: %{ark_name => schema}, enums: %{}}
  end

  defp registry_with_enum(ark_name) do
    {name, ns} =
      case String.split(ark_name, "::") do
        [n] -> {n, nil}
        parts -> {List.last(parts), parts |> Enum.drop(-1) |> Enum.join("::")}
      end

    enum = %ArkEnum{
      name: name,
      object_namespace: ns,
      enum_class: :uint8,
      enum_type: :value,
      values: %{}
    }

    %Registry{schemas: %{}, enums: %{ark_name => enum}}
  end

  # Evaluate the typespec AST in a fresh module to check it compiles.
  defp compiles?(ast) do
    unique = System.unique_integer([:positive])
    mod_name = Module.concat(TypeSpecTest.Tmp, :"M#{unique}")

    Code.eval_quoted(
      quote do
        defmodule unquote(mod_name) do
          @type t :: unquote(ast)
        end
      end
    )

    true
  rescue
    _ -> false
  end

  # ---------------------------------------------------------------------------
  # Primitive types
  # ---------------------------------------------------------------------------

  describe "primitive types" do
    test "bool" do
      ast = TypeSpec.for_field(field("bool"), empty_registry(), Ns)
      assert ast == quote(do: boolean())
    end

    test "string" do
      assert TypeSpec.for_field(field("string"), empty_registry(), Ns) == quote(do: String.t())
    end

    test "guid" do
      assert TypeSpec.for_field(field("guid"), empty_registry(), Ns) == quote(do: String.t())
    end

    test "byte_buffer" do
      assert TypeSpec.for_field(field("byte_buffer"), empty_registry(), Ns) == quote(do: binary())
    end

    test "uint8" do
      assert TypeSpec.for_field(field("uint8"), empty_registry(), Ns) ==
               quote(do: non_neg_integer())
    end

    test "uint16" do
      assert TypeSpec.for_field(field("uint16"), empty_registry(), Ns) ==
               quote(do: non_neg_integer())
    end

    test "uint32" do
      assert TypeSpec.for_field(field("uint32"), empty_registry(), Ns) ==
               quote(do: non_neg_integer())
    end

    test "uint64" do
      assert TypeSpec.for_field(field("uint64"), empty_registry(), Ns) ==
               quote(do: non_neg_integer())
    end

    test "int8" do
      assert TypeSpec.for_field(field("int8"), empty_registry(), Ns) == quote(do: integer())
    end

    test "int16" do
      assert TypeSpec.for_field(field("int16"), empty_registry(), Ns) == quote(do: integer())
    end

    test "int32" do
      assert TypeSpec.for_field(field("int32"), empty_registry(), Ns) == quote(do: integer())
    end

    test "int64" do
      assert TypeSpec.for_field(field("int64"), empty_registry(), Ns) == quote(do: integer())
    end

    test "float" do
      assert TypeSpec.for_field(field("float"), empty_registry(), Ns) == quote(do: float())
    end

    test "double" do
      assert TypeSpec.for_field(field("double"), empty_registry(), Ns) == quote(do: float())
    end

    test "duration" do
      assert TypeSpec.for_field(field("duration"), empty_registry(), Ns) == quote(do: integer())
    end

    test "steady_time_point" do
      assert TypeSpec.for_field(field("steady_time_point"), empty_registry(), Ns) ==
               quote(do: integer())
    end

    test "system_time_point" do
      assert TypeSpec.for_field(field("system_time_point"), empty_registry(), Ns) ==
               quote(do: integer())
    end
  end

  # ---------------------------------------------------------------------------
  # Enum
  # ---------------------------------------------------------------------------

  describe "enum type" do
    test "enum in registry returns atom()" do
      registry = registry_with_enum("my::Status")
      f = field("enum", %{object_type: "my::Status"})
      assert TypeSpec.for_field(f, registry, Ns) == quote(do: atom())
    end

    test "enum not in registry raises" do
      f = field("enum", %{object_type: "my::Missing"})

      assert_raise ArgumentError, ~r/enum type "my::Missing"/, fn ->
        TypeSpec.for_field(f, empty_registry(), Ns)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Object
  # ---------------------------------------------------------------------------

  describe "object type" do
    test "object in registry returns Module.t()" do
      registry = registry_with_schema("my::ns::Thing")
      f = field("object", %{object_type: "my::ns::Thing"})
      ast = TypeSpec.for_field(f, registry, Prefix)

      assert Macro.to_string(ast) == "Prefix.My.Ns.Thing.t()"
      assert compiles?(ast)
    end

    test "object not in registry raises" do
      f = field("object", %{object_type: "my::Missing"})

      assert_raise ArgumentError, ~r/object type "my::Missing"/, fn ->
        TypeSpec.for_field(f, empty_registry(), Ns)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Variant
  # ---------------------------------------------------------------------------

  describe "variant type" do
    test "single variant returns single Module.t()" do
      registry = registry_with_schema("my::A")
      f = field("variant", %{variant_types: [%Variant{index: 1, object_type: "my::A"}]})
      ast = TypeSpec.for_field(f, registry, Ns)
      assert Macro.to_string(ast) == "Ns.My.A.t()"
    end

    test "multiple variants returns union type" do
      registry = %Registry{
        schemas:
          Map.merge(
            registry_with_schema("my::A").schemas,
            registry_with_schema("my::B").schemas
          ),
        enums: %{}
      }

      vtypes = [
        %Variant{index: 1, object_type: "my::A"},
        %Variant{index: 2, object_type: "my::B"}
      ]

      f = field("variant", %{variant_types: vtypes})
      ast = TypeSpec.for_field(f, registry, Ns)
      assert Macro.to_string(ast) == "Ns.My.A.t() | Ns.My.B.t()"
      assert compiles?(ast)
    end

    test "variant with missing type raises" do
      f = field("variant", %{variant_types: [%Variant{index: 1, object_type: "my::Missing"}]})

      assert_raise ArgumentError, ~r/variant type "my::Missing"/, fn ->
        TypeSpec.for_field(f, empty_registry(), Ns)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Container types
  # ---------------------------------------------------------------------------

  describe "array / arraylist" do
    test "arraylist of strings" do
      f = field("arraylist", %{ctr_value_type: field("string")})
      assert TypeSpec.for_field(f, empty_registry(), Ns) == quote(do: [String.t()])
    end

    test "array of uint32" do
      f = field("array", %{ctr_value_type: field("uint32"), array_size: 3})
      assert TypeSpec.for_field(f, empty_registry(), Ns) == quote(do: [non_neg_integer()])
    end

    test "arraylist of objects" do
      registry = registry_with_schema("ns::Item")
      f = field("arraylist", %{ctr_value_type: field("object", %{object_type: "ns::Item"})})
      ast = TypeSpec.for_field(f, registry, Prefix)
      assert Macro.to_string(ast) == "[Prefix.Ns.Item.t()]"
    end
  end

  describe "dictionary" do
    test "string to int32" do
      f =
        field("dictionary", %{
          ctr_key_type: field("string"),
          ctr_value_type: field("int32")
        })

      assert TypeSpec.for_field(f, empty_registry(), Ns) ==
               quote(do: %{optional(String.t()) => integer()})
    end

    test "string to object" do
      registry = registry_with_schema("ns::Val")

      f =
        field("dictionary", %{
          ctr_key_type: field("string"),
          ctr_value_type: field("object", %{object_type: "ns::Val"})
        })

      ast = TypeSpec.for_field(f, registry, Prefix)
      assert Macro.to_string(ast) == "%{optional(String.t()) => Prefix.Ns.Val.t()}"
    end
  end

  # ---------------------------------------------------------------------------
  # nullable option
  # ---------------------------------------------------------------------------

  describe "nullable option" do
    test "nullable: true wraps type with | nil" do
      ast = TypeSpec.for_field(field("string"), empty_registry(), Ns, nullable: true)
      assert ast == quote(do: String.t() | nil)
    end

    test "nullable: false (default) does not wrap" do
      ast = TypeSpec.for_field(field("string"), empty_registry(), Ns, nullable: false)
      assert ast == quote(do: String.t())
    end

    test "nullable: true on object type" do
      registry = registry_with_schema("ns::Thing")
      f = field("object", %{object_type: "ns::Thing"})
      ast = TypeSpec.for_field(f, registry, Ns, nullable: true)
      assert Macro.to_string(ast) == "Ns.Ns.Thing.t() | nil"
    end
  end
end
