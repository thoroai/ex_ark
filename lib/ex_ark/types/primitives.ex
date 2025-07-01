defmodule ExArk.Types.Primitives do
  @moduledoc """
  Module for handling primitive types
  """

  import Bitwise

  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result, as: Result
  alias ExArk.Serdes.OutputStream
  alias ExArk.Types
  alias ExArk.Utilities

  @spec read(Types.primitive_type() | String.t(), InputStream.t()) :: {:ok, Result.t()} | InputStream.failure()
  def read(typestr, %InputStream{} = stream) when is_binary(typestr), do: read(String.to_existing_atom(typestr), stream)

  def read(:uint8, %InputStream{bytes: <<v::little-unsigned-integer-size(8), _rest::binary>>} = stream) do
    {:ok, %Result{stream: InputStream.advance(stream, 1), reified: v}}
  end

  def read(
        :uint16,
        %InputStream{bytes: <<v::little-unsigned-integer-size(16), _rest::binary>>} = stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 2), reified: v}}
  end

  def read(
        :uint32,
        %InputStream{bytes: <<v::little-unsigned-integer-size(32), _rest::binary>>} = stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 4), reified: v}}
  end

  def read(
        :uint64,
        %InputStream{bytes: <<v::little-unsigned-integer-size(64), _rest::binary>>} = stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 8), reified: v}}
  end

  def read(:int8, %InputStream{bytes: <<v::little-signed-integer-size(8), _rest::binary>>} = stream) do
    {:ok, %Result{stream: InputStream.advance(stream, 1), reified: v}}
  end

  def read(:int16, %InputStream{bytes: <<v::little-signed-integer-size(16), _rest::binary>>} = stream) do
    {:ok, %Result{stream: InputStream.advance(stream, 2), reified: v}}
  end

  def read(:int32, %InputStream{bytes: <<v::little-signed-integer-size(32), _rest::binary>>} = stream) do
    {:ok, %Result{stream: InputStream.advance(stream, 4), reified: v}}
  end

  def read(:int64, %InputStream{bytes: <<v::little-signed-integer-size(64), _rest::binary>>} = stream) do
    {:ok, %Result{stream: InputStream.advance(stream, 8), reified: v}}
  end

  def read(:float, %InputStream{bytes: <<bytes::binary-size(4), _rest::binary>>} = stream) do
    <<raw::little-unsigned-size(32)>> = bytes
    sign = raw >>> 31 &&& 0x1
    exponent = raw >>> 23 &&& 0xFF
    fraction = raw &&& 0x7FFFFF
    v = decode_float(sign, exponent, fraction, bytes)

    {:ok, %Result{stream: InputStream.advance(stream, 4), reified: v}}
  end

  def read(:double, %InputStream{bytes: <<bytes::binary-size(8), _rest::binary>>} = stream) do
    <<raw::little-unsigned-size(64)>> = bytes
    sign = raw >>> 63 &&& 0x1
    exponent = raw >>> 52 &&& 0x7FF
    fraction = raw &&& 0xFFFFFFFFFFFFF
    v = decode_double(sign, exponent, fraction, bytes)

    {:ok, %Result{stream: InputStream.advance(stream, 8), reified: v}}
  end

  def read(:bool, %InputStream{bytes: <<0::size(8), _rest::binary>>, offset: _offset} = stream) do
    {:ok, %Result{stream: InputStream.advance(stream, 1), reified: false}}
  end

  def read(:bool, %InputStream{bytes: <<_::size(8), _rest::binary>>} = stream) do
    {:ok, %Result{stream: InputStream.advance(stream, 1), reified: true}}
  end

  #
  # +-------------------------------+---------------------+
  # | Length (N) in bytes (32 bits) | Binary (N * 8 bits) |
  # +-------------------------------+---------------------+
  #

  def read(
        :byte_buffer,
        %InputStream{
          bytes: <<len::little-unsigned-integer-size(32), bb::bytes-size(len), _rest::binary>>
        } = stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 4 + len), reified: bb}}
  end

  def read(
        :duration,
        %InputStream{bytes: <<v::little-signed-integer-size(64), _rest::binary>>} = stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 8), reified: v}}
  end

  def read(
        :guid,
        %InputStream{bytes: <<hi::binary-size(8), lo::binary-size(8), _rest::binary>>} = stream
      ) do
    hi = Utilities.reverse_binary(hi, 8)
    lo = Utilities.reverse_binary(lo, 8)

    {:ok, %Result{stream: InputStream.advance(stream, 16), reified: Ecto.UUID.load!(hi <> lo)}}
  rescue
    ArgumentError ->
      {:error, :bad_guid, nil, %Result{stream: stream}}
  end

  def read(
        :steady_time_point,
        %InputStream{bytes: <<v::little-unsigned-integer-size(64), _rest::binary>>} = stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 8), reified: v}}
  end

  def read(
        :system_time_point,
        %InputStream{bytes: <<v::little-unsigned-integer-size(64), _rest::binary>>} = stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 8), reified: v}}
  end

  #
  # +-------------------------------+---------------------+
  # | Length (N) in bytes (32 bits) | Binary (N * 8 bits) |
  # +-------------------------------+---------------------+
  #

  def read(
        :string,
        # credo:disable-for-next-line
        %InputStream{
          bytes: <<len::little-unsigned-integer-size(32), s::bytes-size(len), _rest::binary>>
        } =
          stream
      ) do
    {:ok, %Result{stream: InputStream.advance(stream, 4 + len), reified: s}}
  end

  @spec write(Types.primitive_type() | String.t(), any(), OutputStream.t()) ::
          {:ok, OutputStream.t()} | {:error, any()}
  def write(type, value, stream) when is_binary(type), do: write(String.to_existing_atom(type), value, stream)

  def write(:uint8, value, stream) do
    bytes = <<value::little-unsigned-integer-size(8)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:uint16, value, stream) do
    bytes = <<value::little-unsigned-integer-size(16)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:uint32, value, stream) do
    bytes = <<value::little-unsigned-integer-size(32)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:uint64, value, stream) do
    bytes = <<value::little-unsigned-integer-size(64)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:int8, value, stream) do
    bytes = <<value::little-signed-integer-size(8)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:int16, value, stream) do
    bytes = <<value::little-signed-integer-size(16)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:int32, value, stream) do
    bytes = <<value::little-signed-integer-size(32)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:int64, value, stream) do
    bytes = <<value::little-signed-integer-size(64)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:float, value, stream) do
    bytes = encode_float(value)
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:double, value, stream) do
    bytes = encode_double(value)
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:bool, value, stream) do
    bytes = if value, do: <<1::size(8)>>, else: <<0::size(8)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  #
  # +-------------------------------+---------------------+
  # | Length (N) in bytes (32 bits) | Binary (N * 8 bits) |
  # +-------------------------------+---------------------+
  #

  def write(:byte_buffer, value, stream) do
    len = byte_size(value)
    bytes = <<len::little-unsigned-integer-size(32)>> <> value
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:duration, value, stream) do
    bytes = <<value::little-signed-integer-size(64)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:guid, value, stream) do
    uuid_binary = Ecto.UUID.dump!(value)
    hi = Utilities.reverse_binary(binary_part(uuid_binary, 0, 8), 8)
    lo = Utilities.reverse_binary(binary_part(uuid_binary, 8, 8), 8)
    bytes = hi <> lo
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:steady_time_point, value, stream) do
    bytes = <<value::little-unsigned-integer-size(64)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(:system_time_point, value, stream) do
    bytes = <<value::little-unsigned-integer-size(64)>>
    {:ok, OutputStream.append(stream, bytes)}
  end

  #
  # +-------------------------------+---------------------+
  # | Length (N) in bytes (32 bits) | Binary (N * 8 bits) |
  # +-------------------------------+---------------------+
  #

  def write(:string, value, stream) do
    len = byte_size(value)
    bytes = <<len::little-unsigned-integer-size(32)>> <> value
    {:ok, OutputStream.append(stream, bytes)}
  end

  def write(type, value, _stream), do: {:error, {:invalid_value_for_type, type, value}}

  defp decode_double(0, 0x7FF, 0, _bytes), do: :positive_infinity
  defp decode_double(1, 0x7FF, 0, _bytes), do: :negative_infinity
  defp decode_double(_sign, 0x7FF, _fraction, _bytes), do: :nan
  defp decode_double(_sign, _exponent, _fraction, <<v::little-float-size(64)>> = _bytes), do: v

  defp encode_double(:positive_infinity), do: <<0 <<< 63 ||| 0x7FF <<< 52::little-unsigned-size(64)>>
  defp encode_double(:negative_infinity), do: <<1 <<< 63 ||| 0x7FF <<< 52::little-unsigned-size(64)>>
  defp encode_double(:nan), do: <<0 <<< 63 ||| 0x7FF <<< 52 ||| 1 <<< 51::little-unsigned-size(64)>>
  defp encode_double(value) when is_float(value), do: <<value::little-float-size(64)>>

  defp decode_float(0, 0xFF, 0, _bytes), do: :positive_infinity
  defp decode_float(1, 0xFF, 0, _bytes), do: :negative_infinity
  defp decode_float(_sign, 0xFF, _fraction, _bytes), do: :nan
  defp decode_float(_sign, _exponent, _fraction, <<v::little-float-size(32)>> = _bytes), do: v

  defp encode_float(:positive_infinity), do: <<0 <<< 31 ||| 0xFF <<< 23::little-unsigned-size(32)>>
  defp encode_float(:negative_infinity), do: <<1 <<< 31 ||| 0xFF <<< 23::little-unsigned-size(32)>>
  defp encode_float(:nan), do: <<0 <<< 31 ||| 0xFF <<< 23 ||| 1 <<< 22::little-unsigned-size(32)>>
  defp encode_float(value) when is_float(value), do: <<value::little-float-size(32)>>
end
