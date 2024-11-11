defmodule ExArk.Ir.Schema do
  @moduledoc """
  Schema information.
  """

  use TypedStruct
  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.Field
  alias ExArk.Ir.Group
  alias ExArk.Ir.SourceLocation
  alias ExArk.Utilities

  union_type attribute_type :: [:final]

  typedstruct enforce: true do
    field :name, String.t()
    field :object_namespace, String.t()
    field :fields, [Field.t()]
    field :groups, [Group.t()]
    field :source_location, SourceLocation.t()
    field :attributes, [attribute_type], enforce: false
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    fields =
      for field_json <- json.fields do
        Field.from_json(field_json)
      end

    groups =
      for group_json <- json.groups do
        Group.from_json(group_json)
      end

    attributes =
      json
      |> Map.get(:attributes, %{})
      |> Map.keys()
      |> Enum.map(&Utilities.ensure_existing_atom(&1))

    struct(__MODULE__, %{
      fields: fields,
      groups: groups,
      name: json.name,
      object_namespace: json.object_namespace,
      source_location: SourceLocation.from_json(json.source_location),
      attributes: attributes
    })
  end
end
