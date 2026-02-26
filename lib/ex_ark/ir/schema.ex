defmodule ExArk.Ir.Schema do
  @moduledoc """
  IR representation of an Ark schema definition.

  A schema describes a structured object type with named fields and optional
  versioned field groups. It is the Elixir equivalent of a single `struct` or
  `class` definition in an Ark `.rbuf` file.

  ## Fields

    * `:name` — unqualified schema name (e.g. `"MySchema"`)
    * `:object_namespace` — optional namespace string (e.g. `"my::Namespace"`);
      `nil` for top-level schemas
    * `:fields` — list of `ExArk.Ir.Field` structs for the schema's fields
    * `:groups` — list of `ExArk.Ir.Group` structs for optional versioned groups
    * `:source_location` — optional `ExArk.Ir.SourceLocation` indicating where
      the schema was defined in the source `.rbuf` file
    * `:attributes` — list of schema-level attributes; currently `:final` is the
      only supported attribute
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

  @doc """
  Return `true` if the schema carries the `:final` attribute.

  A final schema cannot be used as a base type for inheritance in Ark.
  """
  @spec final?(t()) :: boolean()
  def final?(%__MODULE__{} = schema), do: Enum.member?(schema.attributes, :final)

  @doc """
  Return the fully-qualified name of the schema.

  If the schema has an `object_namespace`, the name is `"namespace::Name"`.
  Otherwise it is just `"Name"`. This is the key used in `ExArk.Registry`.
  """
  @spec object_name(t()) :: String.t()
  def object_name(%__MODULE__{object_namespace: nil} = schema), do: schema.name
  def object_name(%__MODULE__{} = schema), do: "#{schema.object_namespace}::#{schema.name}"

  @doc """
  Parse a schema from a decoded JSON term (atom-keyed map).

  This is called internally by `ExArk.Registry.from_json/1` when building a
  registry from an `.ir` file.
  """
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

  @doc """
  Serialize a schema struct to a plain map suitable for JSON encoding.

  The output mirrors the `.ir` file format and is used by
  `ExArk.Registry.to_json/1`.
  """
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
