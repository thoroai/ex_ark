defmodule ExArk.Serdes.Json.Fields.Variant do
  @moduledoc """
  Module for handling variants
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Object
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult
  alias ExArk.Types

  @spec read(Reader.t(), Field.t(), Registry.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(%Reader{} = reader, %Field{} = field, %Registry{} = registry) do
    index = reader.decoded["index"]
    variant = Enum.find(field.variant_types, fn variant -> variant.index == index end)

    if variant != nil do
      read_variant(variant, %Reader{decoded: reader.decoded["value"]}, registry)
    else
      {:error, :unknown_variant, nil, %ReaderResult{}}
    end
  end

  defp read_variant(variant, reader, registry) do
    schema = registry.schemas[variant.object_type]
    Object.deserialize(reader, schema, registry, true)
  end

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{} = field, data, %Registry{} = registry) do
    object_type = Types.get_type(data)
    variant = Enum.find(field.variant_types, fn variant -> variant.object_type == object_type end)

    if variant != nil do
      write_variant(variant, data, registry)
    else
      {:error, :unknown_variant, object_type}
    end
  end

  defp write_variant(variant, data, registry) do
    schema = registry.schemas[variant.object_type]

    case Object.serialize(schema, data, registry) do
      {:ok, %WriterResult{encoded: encoded}} ->
        {:ok, %WriterResult{encoded: %{index: variant.index, value: encoded}}}

      error ->
        error
    end
  end
end
