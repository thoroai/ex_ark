defmodule ExArk.Serdes.Json.Fields do
  @moduledoc """
  Module for functions to handle object fields
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Fields.Primitives
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult
  alias ExArk.Types
  alias ExArk.Utilities

  require Logger

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{type: type} = field, data, registry) do
    cond do
      Types.primitive_type?(type) ->
        Primitives.write(type, data)

      Types.complex_type?(type) ->
        write_field_complex(field, data, registry, type)

      true ->
        raise ArgumentError, "Unknown field type: #{inspect(field.type)}"
    end
  end

  @spec write_with_type(String.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write_with_type(type, data, registry) do
    write(Field.new(type), data, registry)
  end

  defp write_field_complex(field, data, registry, type) do
    mod = get_complex_module_for_type(Utilities.ensure_existing_atom(type))

    case mod.write(field, data, registry) do
      {:error, name, context} = error ->
        log_field_error("serializing", field, name, context)
        error

      {:ok, result} ->
        {:ok, result}
    end
  end

  @spec read(Reader.t(), Field.t(), Registry.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(%Reader{} = reader, %Field{type: type} = field, %Registry{} = registry) do
    cond do
      Types.primitive_type?(type) ->
        Primitives.read(type, reader)

      Types.complex_type?(type) ->
        read_field_complex(reader, field, registry, type)

      true ->
        {:error, :unknown_field_type}
    end
  end

  defp read_field_complex(reader, field, registry, type) do
    mod = get_complex_module_for_type(Utilities.ensure_existing_atom(type))

    case mod.read(reader, field, registry) do
      {:error, name, context, _reader} = error ->
        log_field_error("deserializing", field, name, context)
        error

      {:ok, result} ->
        {:ok, result}
    end
  end

  defp get_complex_module_for_type(type) do
    case type do
      :array -> ExArk.Serdes.Json.Fields.Array
      :arraylist -> ExArk.Serdes.Json.Fields.Arraylist
      :dictionary -> ExArk.Serdes.Json.Fields.Dictionary
      :object -> ExArk.Serdes.Json.Fields.Object
      :variant -> ExArk.Serdes.Json.Fields.Variant
      :enum -> ExArk.Serdes.Json.Fields.ArkEnum
    end
  end

  defp log_field_error(operation, %{name: nil} = field, name, context) do
    Logger.error(
      "Got error #{inspect(name)} #{operation} field (object type: #{field.object_type}): #{inspect(context)}",
      domain: [:ex_ark]
    )
  end

  defp log_field_error(operation, field, name, context) do
    Logger.error(
      "Got error #{inspect(name)} #{operation} field #{field.name} (object type: #{field.object_type}): #{inspect(context)}",
      domain: [:ex_ark]
    )
  end
end
