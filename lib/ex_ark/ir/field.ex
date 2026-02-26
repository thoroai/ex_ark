defmodule ExArk.Ir.Field do
  @moduledoc """
  IR representation of a single field within an Ark schema.

  A field carries a `:type` string that names the Ark type (primitive or
  complex). Additional fields are populated depending on the type:

  - **array** — `:array_size` (fixed length) and `:ctr_value_type` (element type)
  - **arraylist** — `:ctr_value_type` (element type)
  - **dictionary** — `:ctr_key_type` and `:ctr_value_type`
  - **object** — `:object_type` (fully-qualified schema name)
  - **variant** — `:variant_types` (list of `ExArk.Ir.Variant`)
  - **enum** — `:object_type` (fully-qualified enum name)

  ## Fields

    * `:name` — field name string; `nil` for anonymous container element types
    * `:type` — Ark type string (e.g. `"int32"`, `"object"`, `"arraylist"`)
    * `:object_type` — fully-qualified name for `object` and `enum` fields
    * `:array_size` — element count for fixed-size `array` fields
    * `:ctr_value_type` — element type descriptor for container fields
    * `:ctr_key_type` — key type descriptor for `dictionary` fields
    * `:variant_types` — list of `ExArk.Ir.Variant` for `variant` fields
    * `:attributes` — list of field attributes: `:removed`, `:packed_timespec`,
      `:optional`, `:constant`
    * `:comments` — optional documentation comment extracted from the source file
  """

  use TypedStruct
  import ExArk.Utilities, only: [maybe_add_map_value: 3, maybe_add_map_value: 4]
  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.Field
  alias ExArk.Ir.Variant
  alias ExArk.Utilities

  @attribute_types [:removed, :packed_timespec, :optional, :constant]
  union_type attribute_type :: @attribute_types

  typedstruct enforce: false do
    field :name, String.t()
    field :type, String.t(), enforce: true
    field :object_type, String.t()
    field :array_size, integer()
    field :ctr_value_type, Field.t()
    field :ctr_key_type, Field.t()
    field :variant_types, [Variant.t()]
    field :attributes, [attribute_type]
    field :comments, String.t()
  end

  @doc """
  Return `true` if the field carries the `:removed` attribute.

  Removed fields are still present in the binary layout for backwards
  compatibility but their values are discarded during deserialization.
  """
  @spec removed?(t()) :: boolean()
  def removed?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :removed)

  @doc """
  Return `true` if the field carries the `:packed_timespec` attribute.

  Packed timespec fields store a timestamp in a compact binary representation.
  """
  @spec packed_timespec?(t()) :: boolean()
  def packed_timespec?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :packed_timespec?)

  @doc """
  Return `true` if the field carries the `:optional` attribute.

  Optional fields belong to a versioned group and may be absent in older
  serialized data; missing optional fields are filled with their default values.
  """
  @spec optional?(t()) :: boolean()
  def optional?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :optional)

  @doc """
  Return `true` if the field carries the `:constant` attribute.

  Constant fields are read-only and their value is fixed by the schema.
  """
  @spec constant?(t()) :: boolean()
  def constant?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :constant)

  @doc """
  Parse a field from a decoded JSON term (atom-keyed map).

  Called internally during registry and schema parsing.
  """
  @spec from_json(term()) :: t()
  def from_json(json) do
    attributes =
      json
      |> Map.get(:attributes, %{})
      |> Map.keys()
      |> Enum.map(&Utilities.ensure_existing_atom(&1))

    ctr_value_type =
      if Map.has_key?(json, :ctr_value_type),
        do: Field.from_json(json.ctr_value_type),
        else: nil

    ctr_key_type =
      if Map.has_key?(json, :ctr_key_type),
        do: Field.from_json(json.ctr_key_type),
        else: nil

    variant_types =
      if Map.has_key?(json, :variant_types),
        do: Enum.map(json.variant_types, fn variant -> Variant.from_json(variant) end),
        else: []

    name =
      if Map.has_key?(json, :name), do: json.name

    struct(__MODULE__, %{
      name: name,
      type: json.type,
      object_type: Map.get(json, :object_type),
      array_size: Map.get(json, :array_size),
      ctr_value_type: ctr_value_type,
      ctr_key_type: ctr_key_type,
      variant_types: variant_types,
      attributes: attributes,
      comments: parse_comments(Map.get(json, :comments))
    })
  end

  @doc """
  Serialize a field struct to a plain map suitable for JSON encoding.
  """
  @spec to_map(t()) :: term()
  def to_map(%__MODULE__{} = field) do
    attributes = Enum.into(field.attributes, %{}, fn attribute -> {attribute, true} end)

    %{"type" => field.type}
    |> maybe_add_map_value("name", field.name)
    |> maybe_add_map_value("object_type", field.object_type)
    |> maybe_add_map_value("array_size", field.array_size)
    |> maybe_add_map_value("ctr_value_type", field.ctr_value_type, &Field.to_map/1)
    |> maybe_add_map_value("ctr_key_type", field.ctr_key_type, &Field.to_map/1)
    |> maybe_add_map_value("attributes", attributes)
    |> maybe_add_map_value("variant_types", field.variant_types, &Variant.to_list/1)
    |> maybe_add_map_value("comments", field.comments)
  end

  @doc """
  Create a minimal field struct with only the `:type` field populated.

  Useful when constructing synthetic field descriptors (e.g. for container
  element types in tests or code generation).
  """
  @spec new(String.t()) :: t()
  def new(type) do
    struct(__MODULE__, %{type: type})
  end

  # Comments may be stored as a plain string or as a list of lines.
  defp parse_comments(nil), do: nil
  defp parse_comments([]), do: nil
  defp parse_comments(lines) when is_list(lines), do: Enum.join(lines, "\n")
  defp parse_comments(comment) when is_binary(comment), do: comment
end
