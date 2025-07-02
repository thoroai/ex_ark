defmodule ExArk.Types.Primitives do
  @moduledoc """
  Module for handling primitive types
  """

  import Bitwise

  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Types
  alias ExArk.Utilities

  @spec read(String.t(), InputStream.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(typestr, %InputStream{} = stream) when is_binary(typestr), do: read(String.to_existing_atom(typestr), stream)

  @spec read(Types.primitive_type(), InputStream.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(:uint8, %InputStream{bytes: <<v::little-unsigned-integer-size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: v}}
  end

  def read(:uint16, %InputStream{bytes: <<v::little-unsigned-integer-size(16), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 2}, reified: v}}
  end

  def read(:uint32, %InputStream{bytes: <<v::little-unsigned-integer-size(32), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4}, reified: v}}
  end

  def read(:uint64, %InputStream{bytes: <<v::little-unsigned-integer-size(64), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end

  def read(:int8, %InputStream{bytes: <<v::little-signed-integer-size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: v}}
  end

  def read(:int16, %InputStream{bytes: <<v::little-signed-integer-size(16), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 2}, reified: v}}
  end

  def read(:int32, %InputStream{bytes: <<v::little-signed-integer-size(32), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4}, reified: v}}
  end

  def read(:int64, %InputStream{bytes: <<v::little-signed-integer-size(64), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end

  def read(:float, %InputStream{bytes: <<bytes::binary-size(4), rest::binary>>, offset: offset} = stream) do
    <<raw::little-unsigned-size(32)>> = bytes
    sign = raw >>> 31 &&& 0x1
    exponent = raw >>> 23 &&& 0xFF
    fraction = raw &&& 0x7FFFFF
    v = decode_float(sign, exponent, fraction, bytes)

    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4}, reified: v}}
  end

  def read(:double, %InputStream{bytes: <<bytes::binary-size(8), rest::binary>>, offset: offset} = stream) do
    <<raw::little-unsigned-size(64)>> = bytes
    sign = raw >>> 63 &&& 0x1
    exponent = raw >>> 52 &&& 0x7FF
    fraction = raw &&& 0xFFFFFFFFFFFFF
    v = decode_double(sign, exponent, fraction, bytes)

    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end

  def read(:bool, %InputStream{bytes: <<0::size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: false}}
  end

  def read(:bool, %InputStream{bytes: <<_::size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: true}}
  end

  #
  # +-------------------------------+---------------------+
  # | Length (N) in bytes (32 bits) | Binary (N * 8 bits) |
  # +-------------------------------+---------------------+
  #

  def read(
        :byte_buffer,
        %InputStream{
          bytes: <<len::little-unsigned-integer-size(32), bb::bytes-size(len), rest::binary>>,
          offset: offset
        } = stream
      ) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4 + len}, reified: bb}}
  end

  def read(:duration, %InputStream{bytes: <<v::little-signed-integer-size(64), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end

  def read(
        :guid,
        %InputStream{bytes: <<hi::binary-size(8), lo::binary-size(8), rest::binary>>, offset: offset} = stream
      ) do
    hi = Utilities.reverse_binary(hi, 8)
    lo = Utilities.reverse_binary(lo, 8)

    {:ok,
     %Result{
       stream: %{stream | bytes: rest, offset: offset + 16},
       reified: Ecto.UUID.load!(hi <> lo)
     }}
  rescue
    ArgumentError ->
      {:error, :bad_guid, nil, %Result{stream: stream}}
  end

  def read(
        :steady_time_point,
        %InputStream{bytes: <<v::little-unsigned-integer-size(64), rest::binary>>, offset: offset} = stream
      ) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end

  def read(
        :system_time_point,
        %InputStream{bytes: <<v::little-unsigned-integer-size(64), rest::binary>>, offset: offset} = stream
      ) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end

  #
  # +-------------------------------+---------------------+
  # | Length (N) in bytes (32 bits) | Binary (N * 8 bits) |
  # +-------------------------------+---------------------+
  #

  def read(
        :string,
        # credo:disable-for-next-line
        %InputStream{bytes: <<len::little-unsigned-integer-size(32), s::bytes-size(len), rest::binary>>, offset: offset} =
          stream
      ) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4 + len}, reified: s}}
  end

  defp decode_double(0, 0x7FF, 0, _bytes), do: :positive_infinity
  defp decode_double(1, 0x7FF, 0, _bytes), do: :negative_infinity
  defp decode_double(_sign, 0x7FF, _fraction, _bytes), do: :nan

  defp decode_double(_sign, _exponent, _fraction, <<v::little-float-size(64)>> = _bytes), do: v

  defp decode_float(0, 0xFF, 0, _bytes), do: :positive_infinity
  defp decode_float(1, 0xFF, 0, _bytes), do: :negative_infinity
  defp decode_float(_sign, 0xFF, _fraction, _bytes), do: :nan

  defp decode_float(_sign, _exponent, _fraction, <<v::little-float-size(32)>> = _bytes), do: v
end
