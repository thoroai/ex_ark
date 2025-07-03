defmodule ExArk.Types.Object do
  @moduledoc """
  Module for handling objects
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Deserialization
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OutputStream

  require Logger

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    schema = registry.schemas[field.object_type]

    case Deserialization.deserialize(stream, schema, registry) do
      {:ok, %Result{} = result} ->
        {:ok, result}

      {:error, _, _, %Result{} = result} = error ->
        Logger.error("Error deserializing schema #{schema.name}: #{inspect(error)}", domain: [:ex_ark])
        {:error, :bad_object, nil, result}
    end
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = _stream, %Field{} = _field, _data, %Registry{} = _registry) do
    raise RuntimeError, "Not implemented yet"
  end
end
