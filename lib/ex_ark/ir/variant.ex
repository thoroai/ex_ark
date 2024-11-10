defmodule ExArk.Ir.Variant do
  @moduledoc """
  Variant information.
  """

  use TypedStruct

  typedstruct enforce: true do
    field :index, integer()
    field :object_type, String.t()
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{index: hd(json), object_type: hd(tl(json))})
  end
end
