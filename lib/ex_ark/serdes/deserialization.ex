defmodule ExArk.Serdes.Deserialization do
  @moduledoc """
  Ark deserialization utilities.
  """

  alias ExArk.Registry
  alias ExArk.Ir.Schema
  alias ExArk.Serdes.BitstreamHeader
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OptionalGroupHeader

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
  def deserialize(%InputStream{} = stream, %Schema{} = schema, %Registry{} = registry) do
    with {:ok, %Result{stream: stream}} <- BitstreamHeader.read(stream),
         {:ok, %Result{stream: stream}} <- deserialize_fields(stream, schema, registry) do
      deserialize_groups(stream, schema, registry)
    end
  end

  defp deserialize_fields(stream, schema, registry) do
    updated_stream =
      Enum.reduce(schema.fields, stream, fn field, stream ->
        {:ok, %Result{stream: updated_stream}} =
          InputStream.read(stream, field, registry)

        updated_stream
      end)

    {:ok, %Result{stream: updated_stream}}
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
        deserialize_fields(group.fields, stream, registry)
      else
        {:ok, %Result{stream: InputStream.advance(stream, header.group_size)}}
      end
    end
  end
end
