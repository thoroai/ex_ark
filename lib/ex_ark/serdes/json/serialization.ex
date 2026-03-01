defmodule ExArk.Serdes.Json.Serialization do
  @moduledoc """
  Ark JSON serialization utilities.
  """

  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.Json.Object
  alias ExArk.Serdes.Json.Writer.Result

  @spec write_object_to_json(Registry.t(), Schema.t(), any()) :: {:ok, String.t()} | {:error, any()}
  def write_object_to_json(%Registry{} = registry, schema, data) do
    case Object.serialize(schema, data, registry) do
      {:ok, %Result{encoded: encoded}} ->
        {:ok, JSON.encode!(encoded)}

      _error ->
        {:error, :serialization_error}
    end
  end
end
