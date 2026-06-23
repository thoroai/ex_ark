defmodule ExArk.Serdes.Binary.InputStream do
  @moduledoc """
  Input stream for deserialization.
  """

  use TypedStruct

  alias ExArk.Serdes.Binary.InputStream

  defmodule Result do
    @moduledoc """
    Typed structure for input stream read results
    """
    use TypedStruct

    typedstruct do
      field :reified, any()
      field :stream, InputStream.t()
    end
  end

  typedstruct enforce: true do
    field :bytes, binary(), default: <<>>
    field :offset, integer(), default: 0
    field :has_more_sections, bool(), default: false
  end

  @spec advance(t(), non_neg_integer()) :: t()
  def advance(%__MODULE__{} = stream, count) do
    <<_drop::binary-size(^count), rest::binary>> = stream.bytes
    %__MODULE__{stream | bytes: rest, offset: stream.offset + count}
  end
end
