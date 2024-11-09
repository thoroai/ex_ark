defmodule ExArk.Ir.Schema do
  @moduledoc """
  Schema information.
  """

  use TypedStruct

  alias ExArk.Ir.Group
  alias ExArk.Ir.Field
  alias ExArk.Ir.SourceLocation

  typedstruct do
    field :name, String.t()
    field :object_namespace, String.t()
    field :fields, [Field.t()]
    field :groups, [Group.t()]
    field :source_location, SourceLocation.t()
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

    struct(__MODULE__, %{
      fields: fields,
      groups: groups,
      name: json.name,
      object_namespace: json.object_namespace,
      source_location: SourceLocation.from_json(json.source_location)
    })
  end
end
