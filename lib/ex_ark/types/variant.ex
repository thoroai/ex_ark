defmodule ExArk.Types.Variant do
  @moduledoc """
  Module for handling variants
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Deserialization
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  #
  # +-------+--------+------+
  # | Index | Length | Type |
  # +-------+--------+------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(
        %InputStream{
          bytes: <<index::little-unsigned-integer-size(8), length::little-unsigned-integer-size(32), rest::binary>>,
          offset: offset
        } = stream,
        %Field{} = field,
        %Registry{} = registry
      ) do
    stream = %{stream | bytes: rest, offset: offset + 5}

    result = Enum.find(field.variant_types, fn {type_index, _type} -> type_index == index end)

    if result != nil do
      type = elem(result, 1)
      schema = registry[type]
      Deserialization.deserialize(stream, schema, registry)
    else
      {:ok, %Result{stream: InputStream.advance(stream, length)}}
    end
  end
end
