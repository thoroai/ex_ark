defmodule ExArk.Serdes.Deserialization do
  @moduledoc """
  Ark deserialization utilities.
  """

  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.BitstreamHeader
  alias ExArk.Serdes.FileTrailer
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OptionalGroupHeader
  alias ExArk.Types.Primitives

  require Logger

  @spec read_object_from_bytes(Registry.t(), Schema.t(), binary()) :: {:ok, any()} | {:error, any()}
  def read_object_from_bytes(%Registry{} = registry, %Schema{} = schema, bytes) do
    with {:ok, content} <- deserialize_trailer(bytes),
         {:ok, %Result{reified: reified}} <- deserialize(%InputStream{bytes: content}, schema, registry) do
      {:ok, reified}
    else
      _error ->
        {:error, :deserialization_error}
    end
  end

  @spec read_generic_object_from_bytes(binary()) :: {:ok, any()} | {:error, any()}
  def read_generic_object_from_bytes(bytes) do
    with {:ok, {content, schema, registry}} <- deserialize_trailer_with_registry(bytes),
         {:ok, %Result{reified: reified}} <- deserialize(%InputStream{bytes: content}, schema, registry) do
      {:ok, reified}
    else
      _error ->
        {:error, :deserialization_error}
    end
  end

  @spec deserialize(InputStream.t(), Schema.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
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
      {:error, name, context, %Result{stream: stream}} = error ->
        Logger.error("Got error #{inspect(name)} at offset #{stream.offset}: #{inspect(context)}", domain: [:ex_ark])
        error
    end
  end

  defp maybe_deserialize_field(stream, field, registry, reified) do
    if Field.optional?(field) do
      case Primitives.read(:bool, stream) do
        {:ok, %Result{stream: stream, reified: false}} ->
          {:ok, %Result{stream: stream, reified: reified}}

        {:ok, %Result{stream: stream, reified: true}} ->
          deserialize_field(stream, field, registry, reified)
      end
    else
      deserialize_field(stream, field, registry, reified)
    end
  end

  defp deserialize_field(stream, field, registry, reified) do
    case InputStream.read(stream, field, registry) do
      {:ok, %Result{stream: stream, reified: value}} ->
        {:ok, %Result{stream: stream, reified: Map.put(reified, String.to_atom(field.name), value)}}

      error ->
        error
    end
  end

  defp deserialize_fields(stream, [] = _fields, _registry, reified),
    do: {:ok, %Result{stream: stream, reified: reified}}

  defp deserialize_fields(stream, [field | rest], registry, reified) do
    with {:ok, %Result{stream: stream, reified: reified}} <-
           maybe_deserialize_field(stream, field, registry, reified) do
      deserialize_fields(stream, rest, registry, reified)
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
