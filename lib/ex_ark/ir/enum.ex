defmodule ExArk.Ir.ArkEnum do
  @moduledoc """
  Enum information.
  """

  use TypedStruct
  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.SourceLocation

  union_type enum_classes :: [:uint8, :uint16, :uint32, :uint64, :int8, :int16, :int32, :int64]
  union_type enum_types :: [:value, :bitmask]

  typedstruct enforce: true do
    field :name, String.t()
    field :object_namespace, String.t()
    field :enum_class, String.t()
    field :enum_type, enum_types
    field :enum_values, %{}
    field :source_location, SourceLocation.t()
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{
      name: json.name,
      object_namespace: json.object_namespace,
      enum_class: String.to_existing_atom(json.enum_class),
      enum_type: String.to_existing_atom(json.enum_type),
      enum_values: json.values,
      source_location: json.source_location
    })
  end
end
