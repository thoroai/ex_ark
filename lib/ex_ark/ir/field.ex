defmodule ExArk.Ir.Field do
  @moduledoc """
  Group information.
  """

  use TypedStruct
  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Utilities

  union_type attribute_type :: [:removed, :packed_timespec, :optional, :constant]

  typedstruct enforce: true do
    field :name, String.t()
    field :type, String.t()
    field :attributes, [attribute_type], enforce: false
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    attributes =
      json
      |> Map.get(:attributes, %{})
      |> Map.keys()
      |> Enum.map(&Utilities.ensure_existing_atom(&1))

    struct(__MODULE__, %{name: json.name, type: json.type, attributes: attributes})
  end
end
