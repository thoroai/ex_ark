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
    ast = EnumBuilder.build(enum, namespace)
    Code.eval_quoted(ast)
    Naming.enum_module(enum, namespace)
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

  describe "build/2 — values/0" do
    test "returns atoms in declaration order (sorted by integer value)" do
      enum = %ArkEnum{
        name: "Mode",
        object_namespace: "test",
        enum_class: :uint8,
        enum_type: :value,
        values: %{Autonomous: 2, Manual: 1, Uninitialized: 0}
      }

      mod = eval_enum(enum, TestEnumNs)

      assert mod.values() == [:Uninitialized, :Manual, :Autonomous]
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

      assert mod.values() == [:OnlyValue]
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
