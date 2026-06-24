defmodule RbufViewer.Editor.DocumentTest do
  use ExUnit.Case, async: true

  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Ir.Variant
  alias ExArk.Registry
  alias RbufViewer.Editor.Document

  test "set_variant_type updates a nested variant inline and preserves the root object" do
    registry = registry()

    document = Document.from_schema(registry, "crl::knight::StoredMission")

    {:ok, document} = Document.add_item(document, [{:field, "task_instructions"}])

    path = [
      {:field, "task_instructions"},
      {:index, 0},
      {:field, "instruction"}
    ]

    {:ok, document} =
      Document.set_variant_type(document, path, "crl::knight::GotoActionZoneInstruction")

    assert document.schema_name == "crl::knight::StoredMission"

    assert [%{instruction: %{__ark_schema: "crl::knight::GotoActionZoneInstruction"}}] =
             document.object.task_instructions
  end

  test "update_value accepts steady_time_point fields as integers" do
    registry = %Registry{
      schemas: %{
        "Example" => %Schema{
          name: "Example",
          object_namespace: nil,
          fields: [%Field{name: "timestamp", type: "steady_time_point"}],
          groups: [],
          attributes: []
        }
      }
    }

    document = Document.from_schema(registry, "Example")

    {:ok, document} = Document.update_value(document, [{:field, "timestamp"}], "123456")

    assert document.object.timestamp == 123_456
  end

  defp registry do
    %Registry{
      schemas: %{
        "crl::knight::StoredMission" => %Schema{
          name: "StoredMission",
          object_namespace: "crl::knight",
          fields: [
            %Field{
              name: "task_instructions",
              type: "arraylist",
              ctr_value_type: %Field{
                type: "object",
                object_type: "crl::knight::TaskInstruction"
              }
            }
          ],
          groups: [],
          attributes: []
        },
        "crl::knight::TaskInstruction" => %Schema{
          name: "TaskInstruction",
          object_namespace: "crl::knight",
          fields: [
            %Field{
              name: "instruction",
              type: "variant",
              variant_types: [
                %Variant{index: 0, object_type: "crl::knight::FollowPathInstruction"},
                %Variant{index: 1, object_type: "crl::knight::GotoActionZoneInstruction"}
              ]
            }
          ],
          groups: [],
          attributes: []
        },
        "crl::knight::FollowPathInstruction" => %Schema{
          name: "FollowPathInstruction",
          object_namespace: "crl::knight",
          fields: [%Field{name: "plan_name", type: "string"}],
          groups: [],
          attributes: []
        },
        "crl::knight::GotoActionZoneInstruction" => %Schema{
          name: "GotoActionZoneInstruction",
          object_namespace: "crl::knight",
          fields: [%Field{name: "zone_name", type: "string"}],
          groups: [],
          attributes: []
        }
      }
    }
  end
end
