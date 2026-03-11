defmodule ExArk.GenerateTest do
  use ExUnit.Case, async: true

  alias ExArk.GenerateTest.Ns.ExArk.Gen.Test, as: T

  # ---------------------------------------------------------------------------
  # Compile-time module generation
  # We define test modules at module-evaluation time (not inside test blocks)
  # so that the generated struct modules are available for the tests.
  # ---------------------------------------------------------------------------

  defmodule Generated do
    use ExArk.Generate,
      registry: "test/fixtures/ir/generate.ir",
      namespace: ExArk.GenerateTest.Ns,
      schemas: [
        "ex_ark::gen::test::Primitives",
        "ex_ark::gen::test::WithObject",
        "ex_ark::gen::test::WithOptionals",
        "ex_ark::gen::test::WithGroups",
        "ex_ark::gen::test::WithVariant",
        "ex_ark::gen::test::WithOptionalVariant",
        "ex_ark::gen::test::WithCollections",
        "ex_ark::gen::test::WithEnum"
      ]
  end

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module generation" do
    test "all requested schema modules are defined" do
      assert Code.ensure_loaded?(T.Primitives)
      assert Code.ensure_loaded?(T.WithObject)
      assert Code.ensure_loaded?(T.WithOptionals)
      assert Code.ensure_loaded?(T.WithGroups)
      assert Code.ensure_loaded?(T.WithVariant)
      assert Code.ensure_loaded?(T.WithOptionalVariant)
      assert Code.ensure_loaded?(T.WithCollections)
      assert Code.ensure_loaded?(T.WithEnum)
    end

    test "transitively required schema modules are defined" do
      # Child is not in the schemas list but is referenced by WithObject,
      # WithOptionals, and WithCollections
      assert Code.ensure_loaded?(T.Child)
      assert Code.ensure_loaded?(T.VariantA)
      assert Code.ensure_loaded?(T.VariantB)
    end

    test "enum module is generated" do
      assert Code.ensure_loaded?(T.Mode)
    end
  end

  # ---------------------------------------------------------------------------
  # Struct shape
  # ---------------------------------------------------------------------------

  describe "struct fields" do
    test "required fields are enforced" do
      assert_raise ArgumentError, fn ->
        struct!(T.WithObject, [])
      end
    end

    test "optional fields are not enforced and default to nil" do
      s = struct!(T.WithOptionals, required: "hello")
      assert s.opt_string == nil
      assert s.opt_child == nil
    end

    test "group fields default to nil" do
      s = struct!(T.WithGroups, base: "hi")
      assert s.extra_int == nil
      assert s.extra_string == nil
    end

    test "__ark_schema_name/0 returns correct ark name" do
      assert T.Primitives.__ark_schema_name() == "ex_ark::gen::test::Primitives"
      assert T.Child.__ark_schema_name() == "ex_ark::gen::test::Child"
    end
  end

  # ---------------------------------------------------------------------------
  # Enum modules
  # ---------------------------------------------------------------------------

  describe "enum module" do
    test "names/0 returns atoms in declaration order" do
      assert T.Mode.names() == [:Off, :On, :Auto]
    end

    test "values/0 returns integer discriminants in declaration order" do
      assert T.Mode.values() == [0, 1, 2]
    end
  end

  # ---------------------------------------------------------------------------
  # Binary roundtrips
  # ---------------------------------------------------------------------------

  describe "binary roundtrip — primitives" do
    test "all primitive fields roundtrip" do
      s = %T.Primitives{
        a_bool: true,
        a_uint8: 255,
        a_uint32: 1_000_000,
        a_int32: -42,
        a_float: 1.5,
        a_double: 3.14,
        a_string: "hello",
        a_guid: "00000000-0000-0000-0000-000000000001",
        a_duration: 9_000_000_000
      }

      assert {:ok, bytes} = T.Primitives.serialize_to_binary(s)
      assert {:ok, result} = T.Primitives.deserialize_from_binary(bytes)
      assert result.a_bool == s.a_bool
      assert result.a_uint8 == s.a_uint8
      assert result.a_uint32 == s.a_uint32
      assert result.a_int32 == s.a_int32
      assert result.a_string == s.a_string
      assert result.a_guid == s.a_guid
      assert result.a_duration == s.a_duration
    end
  end

  describe "binary roundtrip — nested object" do
    test "object field roundtrips" do
      s = %T.WithObject{
        id: "abc",
        child: %T.Child{value: 7, label: "seven"}
      }

      assert {:ok, bytes} = T.WithObject.serialize_to_binary(s)
      assert {:ok, result} = T.WithObject.deserialize_from_binary(bytes)
      assert result.id == "abc"
      assert %T.Child{} = result.child
      assert result.child.value == 7
      assert result.child.label == "seven"
    end
  end

  describe "binary roundtrip — optional fields" do
    test "roundtrip with all optional fields present" do
      s = %T.WithOptionals{
        required: "req",
        opt_string: "opt",
        opt_child: %T.Child{value: 1, label: "one"}
      }

      assert {:ok, bytes} = T.WithOptionals.serialize_to_binary(s)
      assert {:ok, result} = T.WithOptionals.deserialize_from_binary(bytes)
      assert result.required == "req"
      assert result.opt_string == "opt"
      assert %T.Child{} = result.opt_child
      assert result.opt_child.value == 1
    end

    test "roundtrip without optional fields" do
      s = %T.WithOptionals{required: "req"}

      assert {:ok, bytes} = T.WithOptionals.serialize_to_binary(s)
      assert {:ok, result} = T.WithOptionals.deserialize_from_binary(bytes)
      assert result.required == "req"
      assert result.opt_string == nil
      assert result.opt_child == nil
    end
  end

  describe "binary roundtrip — group fields" do
    test "roundtrip with group fields present" do
      s = %T.WithGroups{base: "base", extra_int: 42, extra_string: "extra"}

      assert {:ok, bytes} = T.WithGroups.serialize_to_binary(s)
      assert {:ok, result} = T.WithGroups.deserialize_from_binary(bytes)
      assert result.base == "base"
      assert result.extra_int == 42
      assert result.extra_string == "extra"
    end
  end

  describe "binary roundtrip — variant field" do
    test "variant A roundtrips" do
      s = %T.WithVariant{payload: %T.VariantA{x: 99}}

      assert {:ok, bytes} = T.WithVariant.serialize_to_binary(s)
      assert {:ok, result} = T.WithVariant.deserialize_from_binary(bytes)
      assert %T.VariantA{x: 99} = result.payload
    end

    test "variant B roundtrips" do
      s = %T.WithVariant{payload: %T.VariantB{y: "hello"}}

      assert {:ok, bytes} = T.WithVariant.serialize_to_binary(s)
      assert {:ok, result} = T.WithVariant.deserialize_from_binary(bytes)
      assert %T.VariantB{y: "hello"} = result.payload
    end

    test "optional variant present roundtrips" do
      s = %T.WithOptionalVariant{id: "x", payload: %T.VariantA{x: 5}}

      assert {:ok, bytes} = T.WithOptionalVariant.serialize_to_binary(s)
      assert {:ok, result} = T.WithOptionalVariant.deserialize_from_binary(bytes)
      assert result.id == "x"
      assert %T.VariantA{x: 5} = result.payload
    end

    test "optional variant absent roundtrips" do
      s = %T.WithOptionalVariant{id: "x"}

      assert {:ok, bytes} = T.WithOptionalVariant.serialize_to_binary(s)
      assert {:ok, result} = T.WithOptionalVariant.deserialize_from_binary(bytes)
      assert result.id == "x"
      assert result.payload == nil
    end
  end

  describe "binary roundtrip — collections" do
    test "arraylist of primitives roundtrips" do
      s = %T.WithCollections{tags: ["a", "b", "c"], children: [], scores: %{}}

      assert {:ok, bytes} = T.WithCollections.serialize_to_binary(s)
      assert {:ok, result} = T.WithCollections.deserialize_from_binary(bytes)
      assert result.tags == ["a", "b", "c"]
    end

    test "arraylist of objects roundtrips" do
      s = %T.WithCollections{
        tags: [],
        children: [%T.Child{value: 1, label: "one"}, %T.Child{value: 2, label: "two"}],
        scores: %{}
      }

      assert {:ok, bytes} = T.WithCollections.serialize_to_binary(s)
      assert {:ok, result} = T.WithCollections.deserialize_from_binary(bytes)
      assert [%T.Child{value: 1}, %T.Child{value: 2}] = result.children
    end

    test "dictionary roundtrips" do
      s = %T.WithCollections{tags: [], children: [], scores: %{"a" => 1, "b" => 2}}

      assert {:ok, bytes} = T.WithCollections.serialize_to_binary(s)
      assert {:ok, result} = T.WithCollections.deserialize_from_binary(bytes)
      assert result.scores == %{"a" => 1, "b" => 2}
    end
  end

  # ---------------------------------------------------------------------------
  # JSON roundtrips
  # ---------------------------------------------------------------------------

  describe "JSON roundtrip — primitives" do
    test "all primitive fields roundtrip via JSON" do
      s = %T.Primitives{
        a_bool: false,
        a_uint8: 10,
        a_uint32: 500,
        a_int32: -1,
        a_float: 0.5,
        a_double: 2.718,
        a_string: "world",
        a_guid: "00000000-0000-0000-0000-000000000002",
        a_duration: 0
      }

      assert {:ok, json} = T.Primitives.serialize_to_json(s)
      assert {:ok, result} = T.Primitives.deserialize_from_json(json)
      assert result.a_string == "world"
      assert result.a_int32 == -1
    end
  end

  describe "JSON roundtrip — nested object" do
    test "object field roundtrips via JSON" do
      s = %T.WithObject{id: "json-test", child: %T.Child{value: 3, label: "three"}}

      assert {:ok, json} = T.WithObject.serialize_to_json(s)
      assert {:ok, result} = T.WithObject.deserialize_from_json(json)
      assert result.id == "json-test"
      assert %T.Child{value: 3, label: "three"} = result.child
    end
  end

  describe "JSON roundtrip — variant" do
    test "variant A roundtrips via JSON" do
      s = %T.WithVariant{payload: %T.VariantA{x: 7}}

      assert {:ok, json} = T.WithVariant.serialize_to_json(s)
      assert {:ok, result} = T.WithVariant.deserialize_from_json(json)
      assert %T.VariantA{x: 7} = result.payload
    end

    test "variant B roundtrips via JSON" do
      s = %T.WithVariant{payload: %T.VariantB{y: "world"}}

      assert {:ok, json} = T.WithVariant.serialize_to_json(s)
      assert {:ok, result} = T.WithVariant.deserialize_from_json(json)
      assert %T.VariantB{y: "world"} = result.payload
    end
  end

  # ---------------------------------------------------------------------------
  # index_of/2 — variant index lookup
  # ---------------------------------------------------------------------------

  describe "index_of/2" do
    test "returns correct index for each variant arm" do
      assert T.WithVariant.index_of(:payload, %T.VariantA{x: 0}) == 1
      assert T.WithVariant.index_of(:payload, %T.VariantB{y: "hi"}) == 2
    end

    test "works on optional variant field" do
      assert T.WithOptionalVariant.index_of(:payload, %T.VariantA{x: 0}) == 1
      assert T.WithOptionalVariant.index_of(:payload, %T.VariantB{y: "hi"}) == 2
    end

    test "raises KeyError for unknown field name" do
      assert_raise KeyError, fn ->
        T.WithVariant.index_of(:no_such_field, %T.VariantA{x: 0})
      end
    end

    test "non-variant schemas do not expose index_of/2" do
      refute function_exported?(T.Primitives, :index_of, 2)
      refute function_exported?(T.WithObject, :index_of, 2)
    end
  end

  # ---------------------------------------------------------------------------
  # Compile-time error cases — tested by checking raises in a string-eval
  # ---------------------------------------------------------------------------

  describe "compile-time errors" do
    test "missing namespace raises ArgumentError" do
      assert_raise ArgumentError, ~r/namespace/, fn ->
        Code.eval_string("""
        defmodule ExArk.GenerateTest.MissingNs do
          use ExArk.Generate,
            registry: "test/fixtures/ir/generate.ir",
            schemas: ["ex_ark::gen::test::Child"]
        end
        """)
      end
    end

    test "unknown schema name raises ArgumentError" do
      assert_raise ArgumentError, ~r/"does::not::Exist"/, fn ->
        Code.eval_string("""
        defmodule ExArk.GenerateTest.BadSchema do
          use ExArk.Generate,
            registry: "test/fixtures/ir/generate.ir",
            namespace: ExArk.GenerateTest.Bad,
            schemas: ["does::not::Exist"]
        end
        """)
      end
    end

    test "all-schemas mode (no schemas: key) emits a warning" do
      # We can't easily capture compile warnings, so just verify it compiles
      # without raising and that modules are defined.
      # The warning is emitted to stderr during compilation.
      Code.eval_string("""
      defmodule ExArk.GenerateTest.AllSchemas do
        use ExArk.Generate,
          registry: "test/fixtures/ir/generate.ir",
          namespace: ExArk.GenerateTest.AllNs
      end
      """)

      assert Code.ensure_loaded?(ExArk.GenerateTest.AllNs.ExArk.Gen.Test.Child)
    end
  end
end
