defmodule ExArk.Ir.Field do
  @moduledoc """
  Field information.
  """

  use TypedStruct
  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.Field
  alias ExArk.Ir.Variant
  alias ExArk.Utilities

  union_type attribute_type :: [:removed, :packed_timespec, :optional, :constant]

  typedstruct enforce: false do
    field :name, String.t()
    field :type, String.t(), enforce: true
    field :object_type, String.t()
    field :array_size, integer()
    field :ctr_value_type, Field.t()
    field :ctr_key_type, Field.t()
    field :variant_types, [Variant.t()]
    field :attributes, [attribute_type]
  end

  @spec removed?(t()) :: boolean()
  def removed?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :removed)

  @spec packed_timespec?(t()) :: boolean()
  def packed_timespec?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :packed_timespec?)

  @spec optional?(t()) :: boolean()
  def optional?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :optional)

  @spec constant?(t()) :: boolean()
  def constant?(%__MODULE__{} = field), do: Enum.member?(field.attributes, :constant)

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
        do: Enum.map(json.variant_types, fn variant -> Variant.from_json(variant) end)

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
      attributes: attributes
    })
  end

  @spec new(String.t()) :: t()
  def new(type) do
    struct(__MODULE__, %{type: type})
  end
end
