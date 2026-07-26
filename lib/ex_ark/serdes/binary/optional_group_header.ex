defmodule ExArk.Serdes.Binary.OptionalGroupHeader do
  @moduledoc """
  Optional group header
  """

  use TypedStruct

  alias ExArk.Ir.Group
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.OutputStream

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
  @group_header_size 6

  def read(%InputStream{bytes: <<@magic::4, 0::1, sections::1, 0::2, rest::binary>>, offset: offset} = stream)
      when byte_size(rest) >= 5 do
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
    end
  end

  def read(%InputStream{bytes: <<@magic::4, 0::1, _sections::1, 0::2, _rest::binary>>}),
    do: {:error, :bad_optional_group_header}

  def read(%InputStream{bytes: <<_magic::4, 0::1, _sections::1, 0::2, _rest::binary>>}),
    do: {:error, :bad_magic}

  def read(%InputStream{bytes: <<@magic::4, _::1, _sections::1, _::2, _rest::binary>>}), do: {:error, :bad_header}

  @spec write(OutputStream.t(), Group.t()) :: {:ok, OutputStream.t()} | Binary.serialization_failure()
  def write(%OutputStream{} = stream, %Group{} = group) do
    # Create header byte: magic (4 bits) + unused (1 bit) + sections (1 bit) + unused (2 bits)
    # For now, we don't support multiple sections
    sections = 0
    header_byte = <<@magic::4, 0::1, sections::1, 0::2>>
    <<value::little-unsigned-integer-size(8)>> = header_byte

    # Note: group_size is set to 0 initially, it should be updated after the group is written
    group_size = 0

    with {:ok, stream} <- Primitives.write(:uint8, value, stream),
         {:ok, stream} <- Primitives.write(:uint8, group.identifier, stream) do
      Primitives.write(:uint32, group_size, stream)
    end
  end

  @spec finalize(OutputStream.t(), non_neg_integer(), non_neg_integer()) :: {:ok, OutputStream.t()}
  def finalize(%OutputStream{} = stream, group_header_offset, group_end_offset) do
    # Re-write the header byte to indicate the presence of the data.
    sections = if stream.had_more_sections, do: 1, else: 0

    group_content_offset = group_header_offset + @group_header_size
    group_size = group_end_offset - group_content_offset

    new_bytes =
      :binary.part(stream.bytes, 0, group_header_offset) <>
        <<@magic::4, 0::1, sections::1, 0::2>> <>
        :binary.part(stream.bytes, group_header_offset + 1, 1) <>
        <<group_size::little-unsigned-integer-size(32)>> <>
        :binary.part(
          stream.bytes,
          group_content_offset,
          byte_size(stream.bytes) - group_content_offset
        )

    {:ok, %OutputStream{stream | bytes: new_bytes}}
  end
end
