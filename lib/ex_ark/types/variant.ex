defmodule ExArk.Types.Variant do
  @moduledoc """
  Module for handling variants
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Deserialization
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OutputStream

  #
  # +-------+--------+------+
  # | Index | Length | Type |
  # +-------+--------+------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(
        %InputStream{
          bytes: <<index::little-unsigned-integer-size(8), length::little-unsigned-integer-size(32), _rest::binary>>
        } = stream,
        %Field{} = field,
        %Registry{} = registry
      ) do
    stream = InputStream.advance(stream, 5)

    variant = Enum.find(field.variant_types, fn variant -> variant.index == index end)

    if variant != nil do
      schema = registry.schemas[variant.object_type]
      Deserialization.deserialize(stream, schema, registry)
    else
      {:ok, %Result{stream: InputStream.advance(stream, length)}}
    end
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = _stream, %Field{} = _field, _data, %Registry{} = _registry) do
    {:error, :not_implemented}
  end
end
