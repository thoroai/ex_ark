defmodule ExArk.Serdes.Deserialization do
  @moduledoc """
  Ark deserialization utilities.
  """

  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.BitstreamHeader
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OptionalGroupHeader

  require Logger

  @spec read(Registry.t(), Schema.t(), Path.t()) :: {:ok, any()} | {:error, any()}
  def read(%Registry{} = registry, %Schema{} = schema, path) do
    case File.read(path) do
      {:ok, data} ->
        deserialize(%InputStream{bytes: data}, schema, registry)

      error ->
        error
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
         {:ok, %Result{} = result} <- deserialize_fields(result.stream, schema.fields, registry),
         {:ok, %Result{} = result} <- deserialize_groups(result.stream, schema, registry) do
      {:ok, %Result{result | stream: %{result.stream | has_more_sections: has_more_sections}}}
    else
      error ->
        Logger.error("Got error at offset #{stream.offset}: #{inspect(error)}")
        error
    end
  end

  defp deserialize_field(stream, field, registry) do
    InputStream.read(stream, field, registry)
  end

  defp deserialize_fields(stream, [] = _fields, _registry), do: {:ok, %Result{stream: stream}}

  defp deserialize_fields(stream, [field | rest], registry) do
    with {:ok, %Result{stream: stream}} <- deserialize_field(stream, field, registry) do
      deserialize_fields(stream, rest, registry)
    end
  end

  defp deserialize_groups(%InputStream{has_more_sections: false} = stream, _schema, _registry),
    do: {:ok, %Result{stream: stream}}

  defp deserialize_groups(stream, schema, registry) do
    with {:ok, %Result{stream: stream}} <- deserialize_group(stream, schema, registry) do
      deserialize_groups(stream, schema, registry)
    end
  end

  defp deserialize_group(stream, schema, registry) do
    with {:ok, %Result{stream: stream, reified: header}} <- OptionalGroupHeader.read(stream) do
      group = Enum.find(schema.groups, fn group -> group.identifier == header.identifier end)

      if group != nil do
        deserialize_fields(stream, group.fields, registry)
      else
        {:ok, %Result{stream: InputStream.advance(stream, header.group_size)}}
      end
    end
  end
end
