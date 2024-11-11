defmodule ExArk.Serdes.OptionalGroupHeader do
  @moduledoc """
  Optional group header
  """
  use TypedStruct

  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Types.Primitives

  typedstruct do
    field :identifier, integer()
    field :group_size, integer()
  end

  #
  # +----------------+----------------+------------------+-----------------+
  # | Magic (4 bits) | Unused (1 bit) | Sections (1 bit) | Unused (2 bits) |
  # +----------------+----------------+------------------+-----------------+
  #

  @magic 0xE

  def read(%InputStream{bytes: <<@magic::4, 0::1, sections::1, 0::2, rest::binary>>, offset: offset} = stream) do
    stream = %{stream | bytes: rest, offset: offset + 1, has_more_sections: sections != 0}

    with {:ok, %Result{stream: stream, reified: identifier}} <- Primitives.read(:uint8, stream),
         {:ok, %Result{stream: stream, reified: group_size}} <- Primitives.read(:uint32, stream) do
      {:ok,
       %Result{
         stream: stream,
         reified: %__MODULE__{
           identifier: identifier,
           group_size: group_size
         }
       }}
    else
      _ ->
        {:error, :bad_optional_group_header}
    end
  end

  def read(%InputStream{bytes: <<_magic::4, 0::1, _sections::1, 0::2, _rest::binary>>}),
    do: {:error, :bad_magic}

  def read(%InputStream{bytes: <<@magic::4, _::1, _sections::1, _::2, _rest::binary>>}), do: {:error, :bad_header}
end
