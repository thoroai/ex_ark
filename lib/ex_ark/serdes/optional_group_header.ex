defmodule ExArk.Serdes.OptionalGroupHeader do
  @moduledoc """
  Optional group header
  """
  use TypedStruct

  alias ExArk.Ir.Group
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OutputStream
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

  @spec write(OutputStream.t(), Group.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = stream, %Group{} = group) do
    # Create header byte: magic (4 bits) + unused (1 bit) + sections (1 bit) + unused (2 bits)
    # For now, we don't support multiple sections
    sections = 0
    header_byte = <<@magic::4, 0::1, sections::1, 0::2>>

    # Note: group_size is set to 0 initially, it should be updated after the group is written
    group_size = 0

    with {:ok, stream} <- Primitives.write(:uint8, header_byte, stream),
         {:ok, stream} <- Primitives.write(:uint32, group.identifier, stream) do
      Primitives.write(:uint32, group_size, stream)
    end
  end

  @spec update_size(OutputStream.t(), non_neg_integer(), non_neg_integer()) :: OutputStream.t()
  def update_size(%OutputStream{} = stream, group_start_offset, group_size) do
    size_offset = group_start_offset + 5

    new_bytes =
      :binary.part(stream.bytes, 0, size_offset) <>
        <<group_size::little-unsigned-integer-size(32)>> <>
        :binary.part(stream.bytes, size_offset + 4, byte_size(stream.bytes) - size_offset - 4)

    %OutputStream{stream | bytes: new_bytes}
  end
end
