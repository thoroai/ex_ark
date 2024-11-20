defmodule ExArk.Types.Object do
  @moduledoc """
  Module for handling objects
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Deserialization
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  require Logger

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    schema = registry.schemas[field.object_type]

    case Deserialization.deserialize(stream, schema, registry) do
      {:ok, %Result{} = result} ->
        {:ok, result}

      error ->
        Logger.error("Error deserializing schema #{schema.name}: #{inspect(error)}")
        {:error, :bad_object}
    end
  end
end
