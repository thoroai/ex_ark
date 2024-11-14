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

  @magic_reversed <<0xBC, 0x81, 0xAB, 0x29, 0x6B, 0x4C, 0xEA, 0x1F, 0x53, 0xEB, 0xE9, 0xFC, 0xE8, 0xF0, 0x48, 0xB6>>
  @version 0x1

  def read(data) do
    # Reverse the input binary, so that we can pattern match against the trailer
    # by computing and using the section sizes in the match.
    <<@magic_reversed::binary, @version::big-unsigned-integer-size(8), content_size::big-unsigned-integer-size(64),
      trailer_block_size::big-unsigned-integer-size(32), trailer_reversed::binary-size(trailer_block_size),
      content_reversed::binary-size(content_size)>> = reverse(data)

    {:ok, {reverse(content_reversed), reverse(trailer_reversed)}}
  rescue
    MatchError ->
      {:error, :bad_file_trailer}
  end

  defp reverse(bin), do: :binary.encode_unsigned(:binary.decode_unsigned(bin, :little))
end
