defmodule ExArk.Ir.Schema do
  @moduledoc """
  Schema information.
  """

  use TypedStruct
  import ExArk.Utilities, only: [maybe_add_map_value: 3, maybe_add_map_value: 4]
  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.Field
  alias ExArk.Ir.Group
  alias ExArk.Ir.SourceLocation
  alias ExArk.Utilities

  @attribute_types [:final]
  union_type attribute_type :: @attribute_types

  typedstruct enforce: true do
    field :name, String.t()
    field :object_namespace, String.t(), enforce: false
    field :fields, [Field.t()]
    field :groups, [Group.t()]
    field :source_location, SourceLocation.t(), enforce: false
    field :attributes, [attribute_type], enforce: false
  end

  @spec final?(t()) :: boolean()
  def final?(%__MODULE__{} = schema), do: Enum.member?(schema.attributes, :final)

  @spec object_name(t()) :: String.t()
  def object_name(%__MODULE__{object_namespace: nil} = schema), do: schema.name
  def object_name(%__MODULE__{} = schema), do: "#{schema.object_namespace}::#{schema.name}"

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

    source_location =
      if Map.has_key?(json, :source_location), do: SourceLocation.from_json(json.source_location)

    struct(__MODULE__, %{
      fields: fields,
      groups: groups,
      name: json.name,
      object_namespace: json[:object_namespace],
      source_location: source_location,
      attributes: attributes
    })
  end

  @spec to_map(t()) :: term()
  def to_map(%__MODULE__{} = schema) do
    fields = Enum.map(schema.fields, &Field.to_map/1)
    groups = Enum.map(schema.groups, &Group.to_map/1)
    attributes = Enum.into(schema.attributes, %{}, fn attribute -> {attribute, true} end)

    %{
      "fields" => fields,
      "groups" => groups,
      "name" => schema.name,
      "object_namespace" => schema.object_namespace
    }
    |> maybe_add_map_value("attributes", attributes)
    |> maybe_add_map_value("source_location", schema.source_location, &SourceLocation.to_map/1)
    |> maybe_add_map_value("object_namespace", schema.object_namespace)
  end
end
