defmodule ExArk.Serdes.Binary.Deserialization do
  @moduledoc """
  Ark binary deserialization utilities.
  """

  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.FileTrailer
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.Object

  @spec read_object_from_bytes(Registry.t(), Schema.t(), binary()) :: {:ok, any()} | {:error, any()}
  def read_object_from_bytes(%Registry{} = registry, %Schema{} = schema, bytes) do
    with {:ok, content} <- deserialize_trailer(bytes),
         {:ok, %Result{reified: reified}} <- Object.deserialize(%InputStream{bytes: content}, schema, registry) do
      {:ok, reified}
    else
      _error ->
        {:error, :deserialization_error}
    end
  end

  @spec read_generic_object_from_bytes(binary()) :: {:ok, any()} | {:error, any()}
  def read_generic_object_from_bytes(bytes) do
    with {:ok, {content, schema, registry}} <- deserialize_trailer_with_registry(bytes),
         {:ok, %Result{reified: reified}} <-
           Object.deserialize(%InputStream{bytes: content, offset: 0}, schema, registry) do
      {:ok, %{object: reified, registry: registry}}
    else
      _error ->
        {:error, :deserialization_error}
    end
  end

  defp deserialize_trailer(data) do
    case FileTrailer.read(data) do
      {:ok, {data, _trailer}} ->
        {:ok, data}

      error ->
        error
    end
  end

  defp deserialize_trailer_with_registry(data) do
    with {:ok, {data, trailer}} <- FileTrailer.read(data),
         {:ok, %Result{stream: stream, reified: schema}} <- Primitives.read(:string, %InputStream{bytes: trailer}),
         {:ok, %Result{stream: _stream, reified: registry_raw}} <- Primitives.read(:string, stream),
         {:ok, registry} <- Registry.build(registry_raw) do
      {:ok, {data, registry.schemas[schema], registry}}
    end
  end
end
