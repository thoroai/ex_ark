defmodule ExArk.Serdes.Binary.OutputStream do
  @moduledoc """
  Output stream for serialization.
  """

  use TypedStruct

  typedstruct enforce: true do
    field :bytes, binary(), default: <<>>
    field :offset, non_neg_integer(), default: 0
    field :had_more_sections, bool(), default: false
  end

  @spec advance(t(), non_neg_integer()) :: t()
  def advance(%__MODULE__{bytes: bytes, offset: offset} = stream, count) do
    %{stream | bytes: bytes <> :binary.copy(<<0>>, count), offset: offset + count}
  end

  @spec append(t(), binary()) :: t()
  def append(%__MODULE__{bytes: bytes, offset: offset} = stream, new_bytes) do
    %{stream | bytes: bytes <> new_bytes, offset: offset + byte_size(new_bytes)}
  end
end
