defmodule ExArk.Serdes.Binary.Serialization do
  @moduledoc """
  Ark binary serialization utilities.
  """

  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.FileTrailer
  alias ExArk.Serdes.Binary.Object
  alias ExArk.Serdes.Binary.OutputStream

  @spec write_object_to_bytes(Registry.t(), Schema.t(), any()) :: {:ok, binary()} | {:error, any()}
  def write_object_to_bytes(%Registry{} = registry, %Schema{} = schema, data) do
    with {:ok, stream} <- Object.serialize(%OutputStream{}, schema, data, registry),
         {:ok, %OutputStream{bytes: bytes}} <- serialize_trailer(stream) do
      {:ok, bytes}
    else
      _error ->
        {:error, :serialization_error}
    end
  end

  @spec write_generic_object_to_bytes(Registry.t(), Schema.t(), any()) :: {:ok, binary()} | {:error, any()}
  def write_generic_object_to_bytes(%Registry{} = registry, %Schema{} = schema, data) do
    with {:ok, stream} <- Object.serialize(%OutputStream{}, schema, data, registry),
         {:ok, %OutputStream{bytes: bytes}} <- serialize_trailer(stream, schema, registry) do
      {:ok, bytes}
    else
      _error ->
        {:error, :serialization_error}
    end
  end

  defp serialize_trailer(stream) do
    {:ok, OutputStream.append(stream, FileTrailer.write(stream.offset))}
  end

  defp serialize_trailer(stream, schema, registry) do
    content_end = stream.offset

    with {:ok, object_registry} <- Registry.build_from(registry, schema),
         {:ok, stream} <- Primitives.write(:string, Schema.object_name(schema), stream),
         {:ok, json_registry} <- Registry.to_json(object_registry),
         {:ok, stream} <- Primitives.write(:string, json_registry, stream),
         trailer <- FileTrailer.write(content_end, stream.offset - content_end) do
      {:ok, OutputStream.append(stream, trailer)}
    end
  end
end
