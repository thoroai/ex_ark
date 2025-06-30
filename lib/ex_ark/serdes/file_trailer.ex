defmodule ExArk.Serdes.FileTrailer do
  @moduledoc """
  Serialized file trailer
  """

  #
  # +------------------------------+------------------------------------+
  # | Content (content_size bytes) | Trailer block (trailer_size bytes) |
  # +------------------------------+------------------------------------+
  # +------------------------------+------------------------+------------------+------------------+
  # | Trailer block size (4 bytes) | Content size (8 bytes) | Version (1 byte) | Magic (16 bytes) |
  # +------------------------------+------------------------+------------------+------------------+
  #

  @magic <<0xB6, 0x48, 0xF0, 0xE8, 0xFC, 0xE9, 0xEB, 0x53, 0x1F, 0xEA, 0x4C, 0x6B, 0x29, 0xAB, 0x81, 0xBC>>
  @version 0x1
  @trailer_size 29

  def read(data) do
    # Read the last 29 bytes directly (no reversing needed)
    if byte_size(data) < @trailer_size do
      {:error, :bad_file_trailer}
    else
      trailer_start = byte_size(data) - @trailer_size
      trailer = binary_part(data, trailer_start, @trailer_size)

      # Parse the trailer structure
      case trailer do
        <<trailer_block_size::little-unsigned-integer-size(32), content_size::little-unsigned-integer-size(64),
          @version::little-unsigned-integer-size(8), @magic::binary>> ->
          # Extract content and trailer_block
          content = binary_part(data, 0, content_size)
          trailer_block_start = content_size
          trailer_block = binary_part(data, trailer_block_start, trailer_block_size)
          {:ok, {content, trailer_block}}

        _ ->
          {:error, :bad_file_trailer}
      end
    end
  end

  @spec write(non_neg_integer(), non_neg_integer()) :: binary()
  def write(content_size, trailer_block_size \\ 0) do
    <<trailer_block_size::little-unsigned-integer-size(32), content_size::little-unsigned-integer-size(64),
      @version::little-unsigned-integer-size(8), @magic::binary>>
  end
end
