defmodule ExArk.Serdes.Binary.Fields.Object do
  @moduledoc """
  Module for handling objects
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.Object, as: BinaryObject
  alias ExArk.Serdes.Binary.OutputStream

  require Logger

  @spec read(InputStream.t(), Field.t(), Registry.t()) ::
          {:ok, Result.t()} | Binary.deserialization_failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    schema = registry.schemas[field.object_type]

    case BinaryObject.deserialize(stream, schema, registry) do
      {:ok, %Result{} = result} ->
        {:ok, result}

      {:error, _, _, %Result{} = result} = error ->
        Logger.error("Error deserializing schema #{schema.name}: #{inspect(error)}", domain: [:ex_ark])
        {:error, :bad_object, nil, result}
    end
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) ::
          {:ok, OutputStream.t()} | Binary.serialization_failure()
  def write(%OutputStream{} = stream, %Field{} = field, data, %Registry{} = registry) do
    schema = registry.schemas[field.object_type]

    case BinaryObject.serialize(stream, schema, data, registry) do
      {:ok, %OutputStream{} = stream} ->
        {:ok, stream}

      {:error, name, context, %OutputStream{} = stream} ->
        Logger.error(
          "Error #{inspect(name)} serializing schema #{schema.name} at offset #{stream.offset}: #{inspect(context)}",
          domain: [:ex_ark]
        )

        {:error, :bad_object, nil, stream}
    end
  end
end
