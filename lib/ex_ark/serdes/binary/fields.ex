defmodule ExArk.Serdes.Binary.Fields do
  @moduledoc """
  Module for functions to handle object fields
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.OutputStream
  alias ExArk.Types
  alias ExArk.Utilities

  require Logger

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) ::
          {:ok, OutputStream.t()} | Binary.serialization_failure()
  def write(%OutputStream{} = stream, %Field{type: type} = field, data, registry) do
    cond do
      Types.primitive_type?(type) ->
        Primitives.write(type, data, stream)

      Types.complex_type?(type) ->
        write_field_complex(stream, field, data, registry, type)

      true ->
        raise ArgumentError, "Unknown field type: #{inspect(field.type)}"
    end
  end

  @spec write_with_type(OutputStream.t(), String.t(), any(), Registry.t()) ::
          {:ok, OutputStream.t()} | Binary.serialization_failure()
  def write_with_type(%OutputStream{} = stream, type, data, registry) do
    write(stream, Field.new(type), data, registry)
  end

  defp write_field_complex(stream, field, data, registry, type) do
    mod = get_complex_module_for_type(Utilities.ensure_existing_atom(type))

    case mod.write(stream, field, data, registry) do
      {:error, name, context, stream} = error ->
        log_field_error("serializing", field, name, context, stream)
        error

      {:ok, result} ->
        {:ok, result}
    end
  end

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, Result.t()} | Binary.deserialization_failure()
  def read(%InputStream{} = stream, %Field{type: type} = field, %Registry{} = registry) do
    cond do
      Types.primitive_type?(type) ->
        Primitives.read(type, stream)

      Types.complex_type?(type) ->
        read_field_complex(stream, field, registry, type)

      true ->
        {:error, :unknown_field_type}
    end
  end

  defp read_field_complex(stream, field, registry, type) do
    mod = get_complex_module_for_type(Utilities.ensure_existing_atom(type))

    case mod.read(stream, field, registry) do
      {:error, name, context, stream} = error ->
        log_field_error("deserializing", field, name, context, stream)
        error

      {:ok, result} ->
        {:ok, result}
    end
  end

  defp get_complex_module_for_type(type) do
    case type do
      :array -> ExArk.Serdes.Binary.Fields.Array
      :arraylist -> ExArk.Serdes.Binary.Fields.Arraylist
      :dictionary -> ExArk.Serdes.Binary.Fields.Dictionary
      :object -> ExArk.Serdes.Binary.Fields.Object
      :variant -> ExArk.Serdes.Binary.Fields.Variant
      :enum -> ExArk.Serdes.Binary.Fields.ArkEnum
    end
  end

  defp log_field_error(operation, %{name: nil} = field, name, context, stream) do
    Logger.error(
      "Got error #{inspect(name)} #{operation} field (object type: #{field.object_type}) at offset #{stream.offset}: #{inspect(context)}",
      domain: [:ex_ark]
    )
  end

  defp log_field_error(operation, field, name, context, stream) do
    Logger.error(
      "Got error #{inspect(name)} #{operation} field #{field.name} (object type: #{field.object_type}) at offset #{stream.offset}: #{inspect(context)}",
      domain: [:ex_ark]
    )
  end
end
