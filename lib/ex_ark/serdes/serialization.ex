defmodule ExArk.Serdes.Serialization do
  @moduledoc """
  Ark seserialization utilities.
  """

  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.BitstreamHeader
  alias ExArk.Serdes.FileTrailer
  alias ExArk.Serdes.OptionalGroupHeader
  alias ExArk.Serdes.OutputStream
  alias ExArk.Types
  alias ExArk.Types.Primitives

  require Logger

  @spec write_object_to_bytes(Registry.t(), Schema.t(), any()) :: {:ok, any()} | {:error, any()}
  def write_object_to_bytes(%Registry{} = registry, %Schema{} = schema, data) do
    with {:ok, stream} <- serialize(%OutputStream{}, schema, registry, data),
         {:ok, %OutputStream{bytes: bytes}} <- serialize_trailer(stream) do
      {:ok, bytes}
    else
      _error ->
        {:error, :serialization_error}
    end
  end

  @spec write_generic_object_to_bytes(Registry.t(), Schema.t(), any()) :: {:ok, any()} | {:error, any()}
  def write_generic_object_to_bytes(%Registry{} = registry, %Schema{} = schema, data) do
    with {:ok, stream} <- serialize(%OutputStream{}, schema, registry, data),
         {:ok, %OutputStream{bytes: bytes}} <- serialize_trailer(stream, schema, registry) do
      {:ok, bytes}
    else
      _error ->
        {:error, :serialization_error}
    end
  end

  @spec serialize(OutputStream.t(), Schema.t(), Registry.t(), any()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def serialize(%OutputStream{} = stream, %Schema{} = schema, %Registry{} = registry, data) do
    with {:ok, stream} <- BitstreamHeader.write(stream),
         {:ok, stream} <- serialize_fields(stream, schema.fields, data, registry),
         {:ok, stream} <- serialize_groups(stream, schema.groups, data, registry) do
      {:ok, stream}
    else
      {:error, name, context, %OutputStream{} = stream} = error ->
        Logger.error("Got error #{inspect(name)} offset #{stream.offset}: #{inspect(context)}", domain: [:ex_ark])
        error
    end
  end

  defp serialize_field(stream, field, data, registry) do
    data
    |> Map.get(String.to_existing_atom(field.name))
    |> maybe_serialize_field(stream, field, registry)
  rescue
    ArgumentError ->
      maybe_serialize_field(nil, stream, field, registry)
  end

  defp maybe_serialize_field(nil, stream, field, registry) do
    if Field.optional?(field) do
      Primitives.write(:bool, false, stream)
    else
      default = Types.default_value(field, registry)
      OutputStream.write(stream, field, default, registry)
    end
  end

  defp maybe_serialize_field(data, stream, field, registry) do
    if Field.optional?(field) do
      with {:ok, stream} <- Primitives.write(:bool, true, stream) do
        OutputStream.write(stream, field, data, registry)
      end
    else
      OutputStream.write(stream, field, data, registry)
    end
  end

  defp serialize_fields(stream, [] = _fields, _data, _registry), do: {:ok, stream}

  defp serialize_fields(stream, [field | rest], data, registry) do
    with {:ok, stream} <- serialize_field(stream, field, data, registry) do
      serialize_fields(stream, rest, data, registry)
    end
  end

  defp serialize_groups(stream, [], _data, _registry), do: {:ok, stream}

  defp serialize_groups(stream, [group | rest], data, registry) do
    group_start_offset = stream.offset

    with {:ok, stream} <- OptionalGroupHeader.write(stream, group),
         {:ok, stream} <- serialize_fields(stream, group.fields, data, registry),
         stream <- OptionalGroupHeader.update_size(stream, group_start_offset, stream.offset - group_start_offset) do
      serialize_groups(stream, rest, data, registry)
    end
  end

  defp serialize_trailer(stream) do
    {:ok, OutputStream.append(stream, FileTrailer.write(stream.offset))}
  end

  defp serialize_trailer(stream, schema, registry) do
    with {:ok, object_registry} <- Registry.build_from(registry, schema),
         {:ok, %OutputStream{offset: content_end} = stream} <- Primitives.write(:string, schema.name, stream),
         {:ok, stream} <- Primitives.write(:string, Registry.to_json(object_registry), stream),
         trailer <- FileTrailer.write(content_end, stream.offset - content_end) do
      {:ok, OutputStream.append(stream, trailer)}
    end
  end
end
