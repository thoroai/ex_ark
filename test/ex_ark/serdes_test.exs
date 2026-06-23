defmodule ExArk.SerdesTest do
  use ExUnit.Case, async: true

  alias ExArk.Ir.Field
  alias ExArk.Serdes

  setup do
    registry = ExArk.load_schemas!("test/fixtures/ir/objects.ir")
    {:ok, %{registry: registry}}
  end

  test "default_value for an object includes optional group fields", %{registry: registry} do
    field = %Field{type: "object", object_type: "ex_ark::test::ObjectWithOptionalGroup"}

    assert %{
             __ark_schema: "ex_ark::test::ObjectWithOptionalGroup",
             id: "",
             value: 0,
             group_field_1: "",
             group_field_2: 0
           } = Serdes.default_value(field, registry)
  end
end
