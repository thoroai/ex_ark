defmodule ExArk.Serdes.InputStream do
  @moduledoc """
  Input stream module.
  """

  use TypedStruct

  typedstruct do
    field :bytes, binary()
    field :offset, integer(), default: 0
  end
end
