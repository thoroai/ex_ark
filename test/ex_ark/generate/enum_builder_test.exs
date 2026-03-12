defmodule ExArk.Generate.EnumBuilderTest do
  use ExUnit.Case, async: true

  alias ExArk.Generate.EnumBuilder
  alias ExArk.Generate.Naming
  alias ExArk.Ir.ArkEnum

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Evaluates the generated AST and returns the resulting module atom.
  defp eval_enum(enum, namespace) do
    mod = Naming.enum_module(enum, namespace)

    if Code.ensure_loaded?(mod) do
      mod
    else
      ast = EnumBuilder.build(enum, namespace)
      Code.eval_quoted(ast)
      mod
    end
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "build/2 — module definition" do
    test "defines a module with the correct name" do
      enum = %ArkEnum{
        name: "Status",
        object_namespace: "my::ns",
        enum_class: :uint8,
        enum_type: :value,
        values: %{Active: 0, Inactive: 1}
      }

      mod = eval_enum(enum, MyApp.Ark)

      assert mod == MyApp.Ark.My.Ns.Status
      assert Code.ensure_loaded?(mod)
    end

    test "top-level enum (no namespace)" do
      enum = %ArkEnum{
        name: "Color",
        object_namespace: nil,
        enum_class: :uint8,
        enum_type: :value,
        values: %{Red: 0, Green: 1, Blue: 2}
      }

      mod = eval_enum(enum, TestNs)

      assert mod == TestNs.Color
      assert Code.ensure_loaded?(mod)
    end
  end

  describe "build/2 — names/0" do
    test "returns atoms in declaration order (sorted by integer value)" do
      enum = %ArkEnum{
        name: "Mode",
        object_namespace: "test",
        enum_class: :uint8,
        enum_type: :value,
        values: %{Autonomous: 2, Manual: 1, Uninitialized: 0}
      }

      mod = eval_enum(enum, TestEnumNs)

      assert mod.names() == [:Uninitialized, :Manual, :Autonomous]
    end

    test "single-value enum" do
      enum = %ArkEnum{
        name: "Only",
        object_namespace: "test",
        enum_class: :uint8,
        enum_type: :value,
        values: %{OnlyValue: 0}
      }

      mod = eval_enum(enum, TestEnumNs2)

      assert mod.names() == [:OnlyValue]
    end
  end

  describe "build/2 — values/0" do
    test "returns integer discriminants in declaration order" do
      enum = %ArkEnum{
        name: "ModeInts",
        object_namespace: "test",
        enum_class: :uint8,
        enum_type: :value,
        values: %{Autonomous: 2, Manual: 1, Uninitialized: 0}
      }

      mod = eval_enum(enum, TestEnumIntNs)

      assert mod.values() == [0, 1, 2]
    end
  end

  describe "build/2 — value_for_name/1 and name_for_value/1" do
    setup do
      enum = %ArkEnum{
        name: "StatusCode",
        object_namespace: "test::lookup",
        enum_class: :uint8,
        enum_type: :value,
        values: %{PathComplete: 0, ManualCancel: 1, PathBlocked: 2}
      }

      mod = eval_enum(enum, TestLookupNs)
      {:ok, mod: mod}
    end

    test "value_for_name/1 returns the integer for a known name", %{mod: mod} do
      assert mod.value_for_name(:PathComplete) == 0
      assert mod.value_for_name(:ManualCancel) == 1
      assert mod.value_for_name(:PathBlocked) == 2
    end

    test "value_for_name/1 returns nil for an unknown name", %{mod: mod} do
      assert mod.value_for_name(:Unknown) == nil
    end

    test "name_for_value/1 returns the atom for a known integer", %{mod: mod} do
      assert mod.name_for_value(0) == :PathComplete
      assert mod.name_for_value(1) == :ManualCancel
      assert mod.name_for_value(2) == :PathBlocked
    end

    test "name_for_value/1 returns nil for an unknown integer", %{mod: mod} do
      assert mod.name_for_value(99) == nil
    end
  end

  describe "build/2 — @moduledoc" do
    test "generated AST contains the ark name in the moduledoc string" do
      enum = %ArkEnum{
        name: "OperationalMode",
        object_namespace: "tai::fleet::cloud",
        enum_class: :uint8,
        enum_type: :value,
        values: %{Manual: 1, Autonomous: 2}
      }

      ast = EnumBuilder.build(enum, DocTestNs)
      ast_string = Macro.to_string(ast)

      assert String.contains?(ast_string, "tai::fleet::cloud::OperationalMode")
    end
  end
end
