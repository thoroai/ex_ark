defmodule ExArk.Serdes.Deserialization do
  @moduledoc """
  Ark deserialization utilities.
  """

  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.BitstreamHeader
  alias ExArk.Serdes.FileTrailer
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OptionalGroupHeader
  alias ExArk.Types.Primitives

  require Logger

  @spec read(Registry.t(), Schema.t(), Path.t()) :: {:ok, any()} | {:error, any()}
  def read(%Registry{} = registry, %Schema{} = schema, path) do
    with {:ok, bytes} <- File.read(path),
         {:ok, %Result{reified: reified}} <- deserialize(%InputStream{bytes: bytes}, schema, registry) do
      {:ok, reified}
    end
  end

  @spec read_path(Path.t()) :: {:ok, any()} | {:error, any()}
  def read_path(path) do
    with {:ok, bytes} <- File.read(path) do
      read_bytes(bytes)
    end
  end

  @spec read_bytes(binary()) :: {:ok, any()} | {:error, any()}
  def read_bytes(bytes) do
    with {:ok, {stream, schema, registry}} <- deserialize_type_from(bytes),
         {:ok, %Result{reified: reified}} <- deserialize(stream, schema, registry) do
      {:ok, reified}
    else
      _error ->
        {:error, :deserialization_error}
    end
  end

  @spec deserialize(InputStream.t(), Schema.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | {:error, any()}
  def deserialize(
        %InputStream{has_more_sections: has_more_sections} = stream,
        %Schema{} = schema,
        %Registry{} = registry
      ) do
    stream = %{stream | has_more_sections: false}

    with {:ok, %Result{} = result} <- BitstreamHeader.read(stream),
         {:ok, %Result{reified: fields} = result} <- deserialize_fields(result.stream, schema.fields, registry, %{}),
         {:ok, %Result{reified: groups} = result} <- deserialize_groups(result.stream, schema.groups, registry, %{}) do
      {:ok,
       %Result{
         result
         | stream: %{result.stream | has_more_sections: has_more_sections},
           reified: Map.merge(fields, groups)
       }}
    else
      error ->
        Logger.error("Got error at offset #{stream.offset}: #{inspect(error)}", domain: [:ex_ark])
        error
    end
  end

  defp deserialize_field(stream, field, registry) do
    InputStream.read(stream, field, registry)
  end

  defp deserialize_fields(stream, [] = _fields, _registry, reified),
    do: {:ok, %Result{stream: stream, reified: reified}}

  defp deserialize_fields(stream, [field | rest], registry, reified) do
    with {:ok, %Result{stream: stream, reified: reified_field}} <- deserialize_field(stream, field, registry) do
      deserialize_fields(stream, rest, registry, Map.put(reified, String.to_atom(field.name), reified_field))
    end
  end

  defp deserialize_groups(%InputStream{has_more_sections: false} = stream, _schema, _registry, reified),
    do: {:ok, %Result{stream: stream, reified: reified}}

  defp deserialize_groups(stream, groups, registry, reified) do
    with {:ok, %Result{stream: stream, reified: reified_fields}} <-
           deserialize_group(stream, groups, registry, reified) do
      deserialize_groups(stream, groups, registry, Map.merge(reified, reified_fields))
    end
  end

  defp deserialize_group(stream, groups, registry, reified) do
    with {:ok, %Result{stream: stream, reified: header}} <- OptionalGroupHeader.read(stream) do
      group = Enum.find(groups, fn group -> group.identifier == header.identifier end)

      if group != nil do
        deserialize_fields(stream, group.fields, registry, reified)
      else
        {:ok, %Result{stream: InputStream.advance(stream, header.group_size)}}
      end
    end
  end

  defp deserialize_type_from(data) do
    with {:ok, {data, trailer}} <- FileTrailer.read(data),
         {:ok, %Result{stream: stream, reified: schema}} <- Primitives.read(:string, %InputStream{bytes: trailer}),
         {:ok, %Result{stream: _stream, reified: registry_raw}} <- Primitives.read(:string, stream),
         {:ok, registry} <- Registry.build(registry_raw) do
      {:ok, {%InputStream{bytes: data}, registry.schemas[schema], registry}}
    end
  end
end
