defmodule ExArk.Serdes.Json.Object do
  @moduledoc """
  Ark binary object deserialization.
  """

  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes
  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Fields
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult
  alias ExArk.Types
  alias ExArk.Utilities

  require Logger

  @spec deserialize(Reader.t(), Schema.t(), Registry.t(), boolean()) ::
          {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def deserialize(%Reader{} = reader, %Schema{} = schema, %Registry{} = registry, add_type \\ false) do
    reified = if add_type, do: Types.add_type(%{}, schema), else: %{}

    with {:ok, %ReaderResult{reified: reified}} <- deserialize_fields(reader, schema.fields, registry, reified),
         {:ok, %ReaderResult{reified: reified}} <- deserialize_groups(reader, schema.groups, registry, reified) do
      {:ok, %ReaderResult{reified: reified}}
    else
      {:error, name, context, %ReaderResult{} = _result} = error ->
        Logger.error("Got error #{inspect(name)}: #{inspect(context)}", domain: [:ex_ark])
        error
    end
  end

  defp maybe_deserialize_field(reader, field, registry, reified) do
    optional = Field.optional?(field)
    removed = Field.removed?(field)
    present = Map.has_key?(reader.decoded, field.name)

    cond do
      !optional && !present ->
        {:error, :missing_field, {field}, %ReaderResult{}}

      optional && !present ->
        {:ok, %ReaderResult{reified: reified}}

      removed ->
        {:ok, %ReaderResult{reified: reified}}

      true ->
        deserialize_field(reader, field, registry, reified)
    end
  end

  defp deserialize_field(reader, field, registry, reified) do
    reader = %Reader{decoded: reader.decoded[field.name]}

    case Fields.read(reader, field, registry) do
      {:ok, %ReaderResult{reified: value}} ->
        {:ok, %ReaderResult{reified: Map.put(reified, String.to_atom(field.name), value)}}

      error ->
        error
    end
  end

  defp deserialize_fields(_reader, [] = _fields, _registry, reified),
    do: {:ok, %ReaderResult{reified: reified}}

  defp deserialize_fields(reader, [field | rest], registry, reified) do
    with {:ok, %ReaderResult{reified: reified}} <- maybe_deserialize_field(reader, field, registry, reified) do
      deserialize_fields(reader, rest, registry, reified)
    end
  end

  defp deserialize_groups(_reader, [], _registry, reified), do: {:ok, %ReaderResult{reified: reified}}

  defp deserialize_groups(reader, [group | rest], registry, reified) do
    with {:ok, %ReaderResult{reified: reified_fields}} <- deserialize_group(reader, group, registry, reified) do
      deserialize_groups(reader, rest, registry, Map.merge(reified, reified_fields))
    end
  end

  defp deserialize_group(reader, group, registry, reified) do
    # Check if any field from this group is present in the JSON data
    # If no fields are present, the entire group is considered optional and should be skipped
    has_any_field = Enum.any?(group.fields, fn field -> Map.has_key?(reader.decoded, field.name) end)

    if has_any_field do
      deserialize_fields(reader, group.fields, registry, reified)
    else
      {:ok, %ReaderResult{reified: reified}}
    end
  end

  @spec serialize(Schema.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def serialize(%Schema{} = schema, data, %Registry{} = registry) do
    acc = %{}

    with {:ok, acc} <- serialize_fields(acc, schema.fields, data, registry),
         {:ok, acc} <- serialize_groups(acc, schema.groups, data, registry) do
      {:ok, %WriterResult{encoded: acc}}
    else
      {:error, name, context} = error ->
        Logger.error("Got error #{inspect(name)}: #{inspect(context)}", domain: [:ex_ark])
        error
    end
  end

  defp serialize_field(acc, field, data, registry) do
    data
    |> Map.get(Utilities.ensure_existing_atom(field.name))
    |> maybe_serialize_field(acc, field, registry)
  rescue
    ArgumentError ->
      maybe_serialize_field(nil, acc, field, registry)
  end

  defp maybe_serialize_field(nil, acc, field, registry) do
    if Field.optional?(field) do
      {:ok, acc}
    else
      default = Serdes.default_value(field, registry)
      write_field(acc, field, default, registry)
    end
  end

  defp maybe_serialize_field(data, acc, field, registry) do
    write_field(acc, field, data, registry)
  end

  def write_field(acc, field, data, registry) do
    case Fields.write(field, data, registry) do
      {:ok, %WriterResult{encoded: encoded}} ->
        {:ok, Map.merge(acc, %{field.name => encoded})}

      error ->
        error
    end
  end

  defp serialize_fields(acc, [] = _fields, _data, _registry), do: {:ok, acc}

  defp serialize_fields(acc, [field | rest], data, registry) do
    with {:ok, acc} <- serialize_field(acc, field, data, registry) do
      serialize_fields(acc, rest, data, registry)
    end
  end

  defp serialize_groups(acc, [], _data, _registry), do: {:ok, acc}

  defp serialize_groups(acc, [group | rest], data, registry) do
    with {:ok, acc} <- serialize_fields(acc, group.fields, data, registry) do
      serialize_groups(acc, rest, data, registry)
    end
  end
end
