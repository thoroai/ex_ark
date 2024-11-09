defmodule ExArk.Types.ByteBuffer do
  use ExArk.Serdes.Deserializable

  #
  # +-------------------------------+---------------------+
  # | Length (N) in bytes (32 bits) | Binary (N * 8 bits) |
  # +-------------------------------+---------------------+
  #

  @impl Deserializable
  def read(
        %InputStream{
          bytes: <<len::little-unsigned-integer-size(32), bb::bytes-size(len), rest::binary>>,
          offset: offset
        } =
          stream
      ) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4 + len}, reified: bb}}
  end
end
