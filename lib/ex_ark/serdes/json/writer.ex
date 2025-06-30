defmodule ExArk.Serdes.Json.Writer do
  @moduledoc """
  Output writer for serialization.
  """

  use TypedStruct

  defmodule Result do
    @moduledoc """
    Typed structure for output writer results
    """
    use TypedStruct

    typedstruct do
      field :encoded, any()
    end
  end

  # typedstruct enforce: true do
  #  field :data, term(), default: %{}
  # end
end
