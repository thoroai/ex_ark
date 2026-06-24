defmodule RbufViewer.Ark do
  @moduledoc false

  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.Binary.Deserialization
  alias ExArk.Serdes.Binary.FileTrailer
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result

  def load_registry(path) when is_binary(path) do
    ExArk.load_schemas(path)
  end

  def load_typed_bytes(%Registry{} = registry, schema_name, bytes) when is_binary(bytes) do
    schema = Map.get(registry.schemas, schema_name)

    if is_nil(schema) do
      {:error, {:schema_not_found, schema_name}}
    else
      case ExArk.read_object_from_bytes(registry, schema_name, bytes) do
        {:ok, object} ->
          {:ok,
           %{
             mode: :typed,
             registry: registry,
             schema: schema,
             schema_name: schema_name,
             object: object,
             bytes: bytes
           }}

        error ->
          error
      end
    end
  end

  def load_generic_bytes(bytes) when is_binary(bytes) do
    with {:ok, {content, trailer}} <- FileTrailer.read(bytes),
         {:ok, %Result{stream: stream, reified: schema_name}} <-
           Primitives.read(:string, %InputStream{bytes: trailer}),
         {:ok, %Result{stream: _stream, reified: registry_raw}} <-
           Primitives.read(:string, stream),
         {:ok, registry} <- Registry.build(registry_raw),
         %Schema{} = schema <- Map.get(registry.schemas, schema_name),
         {:ok, object} <- Deserialization.read_object_from_bytes(registry, schema, bytes) do
      {:ok,
       %{
         mode: :generic,
         registry: registry,
         schema: schema,
         schema_name: schema_name,
         object: object,
         bytes: bytes,
         content_bytes: content
       }}
    else
      nil -> {:error, {:schema_not_found, nil}}
      error -> error
    end
  end

  def save(%{registry: registry, schema_name: schema_name, object: object}, mode) do
    case normalize_mode(mode) do
      :generic -> ExArk.write_generic_object_to_bytes(registry, schema_name, object)
      :typed -> ExArk.write_object_to_bytes(registry, schema_name, object)
    end
  end

  def save(%{mode: mode} = payload), do: save(payload, mode)

  defp normalize_mode("generic"), do: :generic
  defp normalize_mode("typed"), do: :typed
  defp normalize_mode(:generic), do: :generic
  defp normalize_mode(:typed), do: :typed
  defp normalize_mode(other), do: other
end
