defmodule ExArk.Types.Object do
  @moduledoc """
  Module for handling objects
  """
  alias ExArk.Ir.ContainerField
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
        Logger.error("Error deserializing schema #{schema.name}, field #{field.name}: #{inspect(error)}")
    end
  end

  @spec read(InputStream.t(), ContainerField.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %ContainerField{} = container_field, %Registry{} = registry) do
    schema = registry.schemas[container_field.object_type]

    case Deserialization.deserialize(stream, schema, registry) do
      {:ok, %Result{} = result} ->
        {:ok, result}

      error ->
        Logger.error("Error deserializing embedded schema #{schema.name}: #{inspect(error)}")
    end
  end
end
