defmodule ExArk.Ir.SourceLocation do
  @moduledoc """
  Group information.
  """

  use TypedStruct

  typedstruct enforce: true do
    field :filename, String.t()
    field :line_number, integer()
  end

  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{filename: json.filename, line_number: json.line_number})
  end
end
