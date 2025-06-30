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
  alias ExArk.Utilities

  require Logger

  @spec write_object_to_bytes(Registry.t(), Schema.t(), any()) :: {:ok, any()} | {:error, any()}
  def write_object_to_bytes(%Registry{} = registry, %Schema{} = schema, data) do
    with {:ok, stream} <- serialize(%OutputStream{}, schema, data, registry),
         {:ok, %OutputStream{bytes: bytes}} <- serialize_trailer(stream) do
      {:ok, bytes}
    else
      _error ->
        {:error, :serialization_error}
    end
  end

  @spec write_generic_object_to_bytes(Registry.t(), Schema.t(), any()) :: {:ok, any()} | {:error, any()}
  def write_generic_object_to_bytes(%Registry{} = registry, %Schema{} = schema, data) do
    with {:ok, stream} <- serialize(%OutputStream{}, schema, data, registry),
         {:ok, %OutputStream{bytes: bytes}} <- serialize_trailer(stream, schema, registry) do
      {:ok, bytes}
    else
      _error ->
        {:error, :serialization_error}
    end
  end

  @spec serialize(OutputStream.t(), Schema.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def serialize(%OutputStream{} = stream, %Schema{} = schema, data, %Registry{} = registry) do
    stream = %{stream | had_more_sections: false}

    header_offset = stream.offset

    with {:ok, stream} <- maybe_write_header(stream, schema),
         {:ok, stream} <- serialize_fields(stream, schema.fields, data, registry),
         {:ok, stream} <- serialize_groups(stream, schema.groups, data, registry),
         {:ok, stream} <- maybe_finalize_header(stream, header_offset, schema) do
      {:ok, stream}
    else
      {:error, name, context, %OutputStream{} = stream} = error ->
        Logger.error("Got error #{inspect(name)} offset #{stream.offset}: #{inspect(context)}", domain: [:ex_ark])
        error
    end
  end

  defp maybe_write_header(stream, schema) do
    if Schema.final?(schema) do
      {:ok, stream}
    else
      BitstreamHeader.write(stream)
    end
  end

  defp maybe_finalize_header(stream, header_offset, schema) do
    if Schema.final?(schema) do
      {:ok, stream}
    else
      BitstreamHeader.finalize(stream, header_offset)
    end
  end

  defp serialize_field(stream, field, data, registry) do
    data
    |> Map.get(Utilities.ensure_existing_atom(field.name))
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

  defp serialize_groups(stream, [], _data, _registry), do: {:ok, %OutputStream{stream | had_more_sections: false}}

  defp serialize_groups(stream, [group | rest], data, registry) do
    group_header_offset = stream.offset
    stream = %{stream | had_more_sections: false}

    with {:ok, stream} <- OptionalGroupHeader.write(stream, group),
         {:ok, %OutputStream{offset: group_end_offset} = stream} <-
           serialize_fields(stream, group.fields, data, registry),
         {:ok, stream} <- serialize_groups(stream, rest, data, registry),
         {:ok, stream} <- OptionalGroupHeader.finalize(stream, group_header_offset, group_end_offset) do
      {:ok, %OutputStream{stream | had_more_sections: true}}
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
