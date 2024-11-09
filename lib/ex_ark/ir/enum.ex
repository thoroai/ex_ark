defmodule ExArk.Ir.ArkEnum do
  @moduledoc """
  Enum information.
  """

  use TypedStruct

  typedstruct do
    field :name, String.t()
    field :object_namespace, String.t()
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{name: json.name, object_namespace: json.object_namespace})
  end
end
