defmodule ExArk.Serdes.BitstreamHeader do
  @moduledoc """
  Bitstream header
  """

  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  #
  # +----------------+----------------+------------------+------------------+
  # | Magic (4 bits) | Groups (1 bit) | Sections (1 bit) | Version (2 bits) |
  # +----------------+----------------+------------------+------------------+
  #

  @magic 0xD
  @version 0x1
  @groups 0x0

  def read(
        %InputStream{bytes: <<@magic::4, @groups::1, sections::1, @version::2, rest::binary>>, offset: offset} = stream
      ) do
    {:ok,
     %Result{
       stream: %{stream | bytes: rest, offset: offset + 1, has_more_sections: sections != 0},
       reified: nil
     }}
  end

  def read(%InputStream{bytes: <<_magic::4, @groups::1, _sections::1, @version::2, _rest::binary>>}),
    do: {:error, :bad_magic}

  def read(%InputStream{bytes: <<@magic::4, @groups::1, _sections::1, _version::2, _rest::binary>>}),
    do: {:error, :bad_version}

  def read(%InputStream{bytes: <<@magic::4, _groups::1, _sections::1, @version::2, _rest::binary>>}),
    do: {:error, :bad_groups}
end
