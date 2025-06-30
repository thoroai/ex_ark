defmodule ExArk.Serdes.Json.Fields.Primitives do
  @moduledoc """
  Module for handling primitive types
  """

  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult
  alias ExArk.Types
  alias ExArk.Utilities

  # Equivalent to <<0x7F, 0x7F, 0xFF, 0xFF>>
  @float_inf 3.4_028_234_663_852_886e+38
  # Equivalent to <<0x7F, 0xEF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>
  @double_inf 1.7_976_931_348_623_157e+308
  # Non-type distinguishing infinity representation
  @inf 1.7_976_931_348_623_157e+308

  @spec read(String.t(), Reader.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(typestr, %Reader{} = reader) when is_binary(typestr),
    do: read(Utilities.ensure_existing_atom(typestr), reader)

  @spec read(Types.primitive_type(), Reader.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(type, %Reader{decoded: decoded} = _reader) when type in [:byte_buffer] do
    {:ok, %ReaderResult{reified: :binary.list_to_bin(decoded)}}
  end

  def read(type, %Reader{decoded: decoded} = _reader) when type in [:float, :double] do
    # Note that we sanitize the raw JSON before decoding it to change all fields
    # that are `Infinity` or `-Infinity` to the infinity value for a double. We
    # use a special constant for that one, to make it obvious that we are not
    # distinguishing between the two types on read.
    value =
      cond do
        decoded == @inf -> :positive_infinity
        decoded == -@inf -> :negative_infinity
        is_nil(decoded) -> :nan
        true -> decoded
      end

    {:ok, %ReaderResult{reified: value}}
  end

  def read(_type, %Reader{decoded: decoded} = _reader) do
    {:ok, %ReaderResult{reified: decoded}}
  end

  @spec write(Types.primitive_type() | String.t(), any()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(type, value) when is_binary(type), do: write(Utilities.ensure_existing_atom(type), value)

  def write(type, value) when type in [:byte_buffer] do
    {:ok, %WriterResult{encoded: :binary.bin_to_list(value)}}
  end

  def write(type, value) when type in [:float] do
    value =
      case value do
        :positive_infinity -> @float_inf
        :negative_infinity -> -@float_inf
        :nan -> nil
        other -> other
      end

    {:ok, %WriterResult{encoded: value}}
  end

  def write(type, value) when type in [:double] do
    value =
      case value do
        :positive_infinity -> @double_inf
        :negative_infinity -> -@double_inf
        :nan -> nil
        other -> other
      end

    {:ok, %WriterResult{encoded: value}}
  end

  def write(_type, value) do
    {:ok, %WriterResult{encoded: value}}
  end

  def float_inf, do: @float_inf
  def double_inf, do: @double_inf
  def inf, do: @inf
end
