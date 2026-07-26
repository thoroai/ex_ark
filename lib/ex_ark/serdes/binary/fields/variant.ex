defmodule ExArk.Serdes.Binary.Fields.Variant do
  @moduledoc """
  Module for handling variants
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.Object
  alias ExArk.Serdes.Binary.OutputStream
  alias ExArk.Types

  #
  # +-------+--------+------+
  # | Index | Length | Type |
  # +-------+--------+------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) ::
          {:ok, Result.t()} | Binary.deserialization_failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    {:ok, %Result{stream: stream, reified: index}} = Primitives.read(:uint8, stream)
    {:ok, %Result{stream: stream, reified: length}} = Primitives.read(:uint32, stream)
    read(index, length, stream, field, registry)
  end

  defp read(index, length, stream, field, registry) do
    variant = Enum.find(field.variant_types, fn variant -> variant.index == index end)

    if variant != nil do
      read_variant(variant, length, stream, registry)
    else
      {:error, :unknown_variant, nil, %Result{stream: stream}}
    end
  end

  defp read_variant(variant, length, stream, registry) do
    schema = registry.schemas[variant.object_type]
    start_offset = stream.offset

    case Object.deserialize(stream, schema, registry, true) do
      {:ok, %Result{} = result} ->
        handle_deserialization(result, start_offset, length)

      error ->
        error
    end
  end

  defp handle_deserialization(%Result{stream: stream} = result, start_offset, length) do
    if stream.offset - start_offset != length do
      {:error, :variant_length_error, {length, stream.offset - start_offset}, result}
    else
      {:ok, result}
    end
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) ::
          {:ok, OutputStream.t()} | Binary.serialization_failure()
  def write(%OutputStream{} = stream, %Field{} = field, data, %Registry{} = registry) do
    object_type = Types.get_type(data)
    variant = Enum.find(field.variant_types, fn variant -> variant.object_type == object_type end)

    if variant != nil do
      write_variant(variant, stream, data, registry)
    else
      {:error, :unknown_variant, object_type, stream}
    end
  end

  defp write_variant(variant, stream, data, registry) do
    {:ok, stream} = Primitives.write(:uint8, variant.index, stream)

    # Placeholder for length, which will be updated at the end of the
    # variant type serialization.
    {:ok, stream} = Primitives.write(:uint32, 0, stream)

    schema = registry.schemas[variant.object_type]
    start_offset = stream.offset

    case Object.serialize(stream, schema, data, registry) do
      {:ok, %OutputStream{} = stream} ->
        update_length(stream, start_offset)

      error ->
        error
    end
  end

  defp update_length(%OutputStream{} = stream, start_offset) do
    length = stream.offset - start_offset
    length_offset = start_offset - 4
    <<prefix::binary-size(^length_offset), _old::little-unsigned-integer-size(32), rest::binary>> = stream.bytes

    {:ok,
     %OutputStream{
       stream
       | bytes: <<prefix::binary-size(start_offset - 4), length::little-unsigned-integer-size(32), rest::binary>>
     }}
  end
end
