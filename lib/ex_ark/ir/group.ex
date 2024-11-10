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
end
