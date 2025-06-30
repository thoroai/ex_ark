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
  alias ExArk.Serdes.Serialization
  alias ExArk.Types.Object
  alias ExArk.Types.Primitives

  #
  # +-------+--------+------+
  # | Index | Length | Type |
  # +-------+--------+------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
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

    case Deserialization.deserialize(stream, schema, registry, true) do
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

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = stream, %Field{} = field, data, %Registry{} = registry) do
    object_type = Object.get_type(data)
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

    case Serialization.serialize(stream, schema, data, registry) do
      {:ok, %OutputStream{} = stream} ->
        update_length(stream, start_offset)

      error ->
        error
    end
  end

  @spec default_value(Field.t(), Registry.t()) :: any()
  def default_value(%Field{} = field, %Registry{} = registry) do
    Object.default_value(hd(field.variant_types).object_type, registry)
  end

  defp update_length(%OutputStream{} = stream, start_offset) do
    length = stream.offset - start_offset
    <<prefix::binary-size(start_offset - 4), _old::little-unsigned-integer-size(32), rest::binary>> = stream.bytes

    {:ok,
     %OutputStream{
       stream
       | bytes: <<prefix::binary-size(start_offset - 4), length::little-unsigned-integer-size(32), rest::binary>>
     }}
  end
end
