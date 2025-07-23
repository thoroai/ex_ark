defmodule ExArk.Ir.Group do
  @moduledoc """
  Group information.
  """

  use TypedStruct

  alias ExArk.Ir.Field

  typedstruct enforce: true do
    field :identifier, integer()
    field :fields, [Field.t()]
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    fields =
      for field_json <- json.fields do
        Field.from_json(field_json)
      end

    struct(__MODULE__, %{identifier: json.identifier, fields: fields})
  end

  @spec to_map(t()) :: term()
  def to_map(%__MODULE__{} = group) do
    %{
      "identifier" => group.identifier,
      "fields" => Enum.map(group.fields, &Field.to_map/1)
    }
  end
end
