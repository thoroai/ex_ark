defmodule ExArk.Serdes.Json.Reader do
  @moduledoc """
  Input reader for deserialization.
  """

  use TypedStruct

  defmodule Result do
    @moduledoc """
    Typed structure for input reader results
    """
    use TypedStruct

    typedstruct do
      field :reified, any()
    end
  end

  typedstruct enforce: true do
    field :decoded, term(), default: %{}
  end
end
