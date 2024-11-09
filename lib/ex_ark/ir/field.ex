defmodule ExArk.Ir.Field do
  @moduledoc """
  Group information.
  """

  use TypedStruct

  typedstruct do
    field :name, String.t()
    field :type, String.t()
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{name: json.name, type: json.type})
  end
end
