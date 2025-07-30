defmodule ExArk.Serdes.Json.Fields.Object do
  @moduledoc """
  Module for handling objects
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Object, as: JsonObject
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult

  require Logger

  @spec read(Reader.t(), Field.t(), Registry.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(%Reader{} = reader, %Field{} = field, %Registry{} = registry) do
    schema = registry.schemas[field.object_type]

    case JsonObject.deserialize(reader, schema, registry) do
      {:ok, %ReaderResult{} = result} ->
        {:ok, result}

      {:error, _, _, %ReaderResult{} = result} = error ->
        Logger.error("Error deserializing schema #{schema.name}: #{inspect(error)}", domain: [:ex_ark])
        {:error, :bad_object, nil, result}
    end
  end

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{} = field, data, %Registry{} = registry) do
    schema = registry.schemas[field.object_type]

    case JsonObject.serialize(schema, data, registry) do
      {:ok, %WriterResult{} = result} ->
        {:ok, result}

      {:error, name, context} ->
        Logger.error(
          "Error #{inspect(name)} serializing schema #{schema.name}: #{inspect(context)}",
          domain: [:ex_ark]
        )

        {:error, :bad_object, nil}
    end
  end
end
