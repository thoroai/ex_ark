defmodule ExArk.Types.Object do
  @moduledoc """
  Module for handling objects
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Deserialization
  alias ExArk.Serdes.InputStream

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    schema = registry[field.object_type]
    Deserialization.deserialize(stream, schema, registry)
  end
end
