defmodule ExArk.Serdes.Binary.Object do
  @moduledoc """
  Ark binary object deserialization.
  """

  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Binary.BitstreamHeader
  alias ExArk.Serdes.Binary.Fields
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.OptionalGroupHeader
  alias ExArk.Serdes.Binary.OutputStream
  alias ExArk.Types
  alias ExArk.Utilities

  require Logger

  @spec deserialize(InputStream.t(), Schema.t(), Registry.t(), boolean()) ::
          {:ok, Result.t()} | Binary.deserialization_failure()
  def deserialize(
        %InputStream{has_more_sections: has_more_sections} = stream,
        %Schema{} = schema,
        %Registry{} = registry,
        add_type \\ false
      ) do
    stream = %{stream | has_more_sections: false}

    reified = if add_type, do: Types.add_type(%{}, schema), else: %{}

    with {:ok, %Result{} = result} <- maybe_read_header(stream, schema),
         {:ok, %Result{reified: reified} = result} <-
           deserialize_fields(result.stream, schema.fields, registry, reified),
         {:ok, %Result{reified: reified} = result} <-
           deserialize_groups(result.stream, schema.groups, registry, reified) do
      {:ok,
       %Result{
         result
         | stream: %{result.stream | has_more_sections: has_more_sections},
           reified: reified
       }}
    else
      {:error, name, context, %Result{stream: stream}} = error ->
        Logger.error("Got error #{inspect(name)} at offset #{stream.offset}: #{inspect(context)}", domain: [:ex_ark])
        error
    end
  end

  defp maybe_read_header(stream, schema) do
    if Schema.final?(schema) do
      {:ok, %Result{stream: stream}}
    else
      BitstreamHeader.read(stream)
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
    case Fields.read(stream, field, registry) do
      {:ok, %Result{stream: stream, reified: value}} ->
        if Field.removed?(field) do
          {:ok, %Result{stream: stream, reified: reified}}
        else
          {:ok, %Result{stream: stream, reified: Map.put(reified, String.to_atom(field.name), value)}}
        end

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

  defp deserialize_groups(%InputStream{has_more_sections: false} = stream, _groups, _registry, reified),
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
        {:ok, %Result{stream: InputStream.advance(stream, header.group_size), reified: reified}}
      end
    end
  end

  @spec serialize(OutputStream.t(), Schema.t(), any(), Registry.t()) ::
          {:ok, OutputStream.t()} | Binary.serialization_failure()
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
      default = Serdes.default_value(field, registry)
      Fields.write(stream, field, default, registry)
    end
  end

  defp maybe_serialize_field(data, stream, field, registry) do
    if Field.optional?(field) do
      with {:ok, stream} <- Primitives.write(:bool, true, stream) do
        Fields.write(stream, field, data, registry)
      end
    else
      Fields.write(stream, field, data, registry)
    end
  end

  defp serialize_fields(stream, [] = _fields, _data, _registry), do: {:ok, stream}

  defp serialize_fields(stream, [field | rest], data, registry) do
    with {:ok, stream} <- serialize_field(stream, field, data, registry) do
      serialize_fields(stream, rest, data, registry)
    end
  end

  defp serialize_groups(%OutputStream{} = stream, [], _data, _registry), do: {:ok, %{stream | had_more_sections: false}}

  defp serialize_groups(%OutputStream{} = stream, [group | rest], data, registry) do
    group_header_offset = stream.offset
    stream = %{stream | had_more_sections: false}

    with {:ok, stream} <- OptionalGroupHeader.write(stream, group),
         {:ok, %OutputStream{offset: group_end_offset} = stream} <-
           serialize_fields(stream, group.fields, data, registry),
         {:ok, stream} <- serialize_groups(stream, rest, data, registry),
         {:ok, stream} <- OptionalGroupHeader.finalize(stream, group_header_offset, group_end_offset) do
      {:ok, %{stream | had_more_sections: true}}
    end
  end
end
