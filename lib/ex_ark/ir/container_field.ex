defmodule ExArk.Ir.ContainerField do
  @moduledoc """
  Container field information.
  """

  use TypedStruct

  typedstruct enforce: false do
    field :type, String.t(), enforce: true
    field :object_type, String.t(), enforce: false
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{type: json.type, object_type: Map.get(json, :object_type)})
  end
end
