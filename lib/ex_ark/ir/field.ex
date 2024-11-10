defmodule ExArk.Ir.Field do
  @moduledoc """
  Field information.
  """

  use TypedStruct
  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.ContainerField
  alias ExArk.Utilities

  union_type attribute_type :: [:removed, :packed_timespec, :optional, :constant]

  typedstruct enforce: false do
    field :name, String.t(), enforce: true
    field :type, String.t(), enforce: true
    field :object_type, String.t()
    field :array_size, integer()
    field :ctr_value_type, ContainerField.t()
    field :ctr_key_type, ContainerField.t()
    field :attributes, [attribute_type]
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    attributes =
      json
      |> Map.get(:attributes, %{})
      |> Map.keys()
      |> Enum.map(&Utilities.ensure_existing_atom(&1))

    ctr_value_type =
      if Map.has_key?(json, :ctr_value_type),
        do: ContainerField.from_json(json.ctr_value_type),
        else: nil

    ctr_key_type =
      if Map.has_key?(json, :ctr_key_type),
        do: ContainerField.from_json(json.ctr_key_type),
        else: nil

    struct(__MODULE__, %{
      name: json.name,
      type: json.type,
      object_type: Map.get(json, :object_type),
      array_size: Map.get(json, :array_size),
      ctr_value_type: ctr_value_type,
      ctr_key_type: ctr_key_type,
      attributes: attributes
    })
  end
end
