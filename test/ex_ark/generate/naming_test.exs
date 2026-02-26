defmodule ExArk.Generate.NamingTest do
  use ExUnit.Case, async: true

  alias ExArk.Generate.Naming
  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Schema

  describe "ark_name_to_segments/1" do
    test "single top-level name (no namespace)" do
      assert Naming.ark_name_to_segments("RobotStatus") == ["RobotStatus"]
    end

    test "lowercase namespace components are capitalised" do
      assert Naming.ark_name_to_segments("tai::fleet::cloud::RobotStatus") ==
               ["Tai", "Fleet", "Cloud", "RobotStatus"]
    end

    test "short lowercase namespace" do
      assert Naming.ark_name_to_segments("ark::TransformMessage2d") ==
               ["Ark", "TransformMessage2d"]
    end

    test "abbreviation namespace component" do
      assert Naming.ark_name_to_segments("crl::knight::TaskType") ==
               ["Crl", "Knight", "TaskType"]
    end

    test "already-PascalCase name is preserved intact" do
      assert Naming.ark_name_to_segments("tai::MySchema") == ["Tai", "MySchema"]
    end

    test "name with digits in middle is preserved" do
      assert Naming.ark_name_to_segments("ark::TransformMessage2d") ==
               ["Ark", "TransformMessage2d"]
    end

    test "single-component name that is already uppercase is unchanged" do
      assert Naming.ark_name_to_segments("MyTopLevel") == ["MyTopLevel"]
    end

    test "deep namespace" do
      assert Naming.ark_name_to_segments("a::b::c::d::E") == ["A", "B", "C", "D", "E"]
    end
  end

  describe "ark_name_to_module/2" do
    test "namespaced name with prefix" do
      result = Naming.ark_name_to_module("tai::fleet::cloud::RobotStatus", MyApp.Ark)
      assert result == MyApp.Ark.Tai.Fleet.Cloud.RobotStatus
    end

    test "top-level name with prefix" do
      result = Naming.ark_name_to_module("TopLevelObject", MyApp.Ark)
      assert result == MyApp.Ark.TopLevelObject
    end

    test "single-segment namespace prefix" do
      result = Naming.ark_name_to_module("tai::fleet::cloud::Foo", Prefix)
      assert result == Prefix.Tai.Fleet.Cloud.Foo
    end

    test "deep prefix concatenates correctly" do
      result = Naming.ark_name_to_module("ark::Bar", My.Deep.Namespace)
      assert result == My.Deep.Namespace.Ark.Bar
    end
  end

  describe "schema_module/2" do
    test "schema with namespace" do
      schema = %Schema{
        name: "RobotStatus",
        object_namespace: "tai::fleet::cloud",
        fields: [],
        groups: []
      }

      assert Naming.schema_module(schema, MyApp.Ark) ==
               MyApp.Ark.Tai.Fleet.Cloud.RobotStatus
    end

    test "schema without namespace (top-level)" do
      schema = %Schema{
        name: "TopLevelObject",
        object_namespace: nil,
        fields: [],
        groups: []
      }

      assert Naming.schema_module(schema, MyApp.Ark) == MyApp.Ark.TopLevelObject
    end
  end

  describe "enum_module/2" do
    test "enum with namespace" do
      enum = %ArkEnum{
        name: "OperationalMode",
        object_namespace: "tai::fleet::cloud",
        enum_class: :uint8,
        enum_type: :value,
        values: %{}
      }

      assert Naming.enum_module(enum, MyApp.Ark) ==
               MyApp.Ark.Tai.Fleet.Cloud.OperationalMode
    end

    test "enum without namespace" do
      enum = %ArkEnum{
        name: "Status",
        object_namespace: nil,
        enum_class: :uint8,
        enum_type: :value,
        values: %{}
      }

      assert Naming.enum_module(enum, MyApp.Ark) == MyApp.Ark.Status
    end
  end
end
