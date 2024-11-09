defmodule ExArk.Serdes.OptionalGroupHeader do
  @moduledoc """
  Optional group header
  """
  use ExArk.Serdes.Deserializable
  use TypedStruct

  alias ExArk.Types.Uint8
  alias ExArk.Types.Uint32
  alias ExArk.Serdes.InputStream, as: Stream

  typedstruct do
    field :has_more_sections, bool()
    field :identifier, integer()
    field :group_size, integer()
  end

  #
  # +----------------+----------------+------------------+------------------+
  # | Magic (4 bits) | Groups (1 bit) | Sections (1 bit) | Version (2 bits) |
  # +----------------+----------------+------------------+------------------+
  #

  @magic 0xE
  @version 0x1
  @groups 0x0

  def read(
        %Stream{
          bytes: <<@magic::4, @groups::1, sections::1, @version::2, rest::binary>>,
          offset: offset
        } = stream
      ) do
    stream = %{stream | bytes: rest, offset: offset + 1}

    with {:ok, %Result{stream: stream, reified: identifier}} <- Uint8.read(stream),
         {:ok, %Result{stream: stream, reified: group_size}} <- Uint32.read(stream) do
      {:ok,
       %Result{
         stream: stream,
         reified: %__MODULE__{
           has_more_sections: sections != 0,
           identifier: identifier,
           group_size: group_size
         }
       }}
    else
      _ ->
        {:error, :bad_opt_group_header}
    end
  end

  def read(%Stream{bytes: <<_magic::4, @groups::1, _sections::1, @version::2, _rest::binary>>}),
    do: {:error, :bad_magic}

  def read(%Stream{bytes: <<@magic::4, @groups::1, _sections::1, _version::2, _rest::binary>>}),
    do: {:error, :bad_version}

  def read(%Stream{bytes: <<@magic::4, _groups::1, _sections::1, @version::2, _rest::binary>>}),
    do: {:error, :bad_groups}
end
