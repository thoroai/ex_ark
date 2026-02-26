defmodule ExArk.Ir.ArkEnum do
  @moduledoc """
  IR representation of an Ark enum definition.

  An Ark enum is a named set of integer constants. It can be a plain *value*
  enum (exactly one variant selected at a time) or a *bitmask* enum (zero or
  more variants combined with bitwise OR).

  ## Fields

    * `:name` — unqualified enum name (e.g. `"Color"`)
    * `:object_namespace` — optional namespace string; `nil` for top-level enums
    * `:enum_class` — the underlying integer type; one of `:uint8`, `:uint16`,
      `:uint32`, `:uint64`, `:int8`, `:int16`, `:int32`, `:int64`
    * `:enum_type` — `:value` for a normal enum, `:bitmask` for a flags enum
    * `:values` — map of variant name atom → integer value
    * `:source_location` — optional `ExArk.Ir.SourceLocation`
  """

  use TypedStruct
  import UnionTypespec, only: [union_type: 1]
  import ExArk.Utilities, only: [ensure_existing_atom: 1, maybe_add_map_value: 3, maybe_add_map_value: 4]

  alias ExArk.Ir.SourceLocation

  @enum_classes [:uint8, :uint16, :uint32, :uint64, :int8, :int16, :int32, :int64]
  @enum_styles [:value, :bitmask]

  union_type enum_class :: @enum_classes
  union_type enum_style :: @enum_styles

  typedstruct enforce: true do
    field :name, String.t()
    field :object_namespace, String.t(), enforce: false
    field :enum_class, enum_class
    field :enum_type, enum_style
    field :values, %{}
    field :source_location, SourceLocation.t(), enforce: false
  end

  @doc """
  Return the fully-qualified name of the enum.

  If the enum has an `object_namespace`, the name is `"namespace::Name"`.
  Otherwise it is just `"Name"`. This is the key used in `ExArk.Registry`.
  """
  @spec object_name(t()) :: String.t()
  def object_name(%__MODULE__{object_namespace: nil} = enum), do: enum.name
  def object_name(%__MODULE__{} = enum), do: "#{enum.object_namespace}::#{enum.name}"

  @doc """
  Parse an enum from a decoded JSON term (atom-keyed map).

  Called internally by `ExArk.Registry.from_json/1`.
  """
  @spec from_json(term()) :: t()
  def from_json(json) do
    source_location =
      if Map.has_key?(json, :source_location), do: SourceLocation.from_json(json.source_location)

    values = if Map.has_key?(json, :values), do: json.values, else: []

    struct(__MODULE__, %{
      name: json.name,
      object_namespace: json[:object_namespace],
      enum_class: parse_enum_class(json.enum_class),
      enum_type: parse_enum_style(json.enum_type),
      values: values,
      source_location: source_location
    })
  end

  # Pattern-matching on string literals ensures the returned atoms appear in
  # this module's bytecode (Atom chunk) and are interned when the module loads.
  # Using String.to_existing_atom via ensure_existing_atom is not safe here
  # because @enum_classes/@enum_styles are only used by the compile-time
  # union_type macro and their atoms are otherwise absent from the Atom chunk.
  defp parse_enum_class("uint8"), do: :uint8
  defp parse_enum_class("uint16"), do: :uint16
  defp parse_enum_class("uint32"), do: :uint32
  defp parse_enum_class("uint64"), do: :uint64
  defp parse_enum_class("int8"), do: :int8
  defp parse_enum_class("int16"), do: :int16
  defp parse_enum_class("int32"), do: :int32
  defp parse_enum_class("int64"), do: :int64
  defp parse_enum_class(other), do: ensure_existing_atom(other)

  defp parse_enum_style("value"), do: :value
  defp parse_enum_style("bitmask"), do: :bitmask
  defp parse_enum_style(other), do: ensure_existing_atom(other)

  @doc """
  Serialize an enum struct to a plain map suitable for JSON encoding.

  Used by `ExArk.Registry.to_json/1`.
  """
  @spec to_map(t()) :: term()
  def to_map(%__MODULE__{} = enum) do
    values = Map.new(enum.values, fn {k, v} -> {to_string(k), v} end)

    %{
      "name" => enum.name,
      "object_namespace" => enum.object_namespace,
      "enum_class" => enum.enum_class,
      "enum_type" => enum.enum_type,
      "values" => values
    }
    |> maybe_add_map_value("source_location", enum.source_location, &SourceLocation.to_map/1)
    |> maybe_add_map_value("object_namespace", enum.object_namespace)
  end
end
