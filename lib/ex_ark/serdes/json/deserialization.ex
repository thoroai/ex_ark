defmodule ExArk.Serdes.Json.Deserialization do
  @moduledoc """
  Ark JSON deserialization utilities.
  """

  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes.Json.Object
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result

  @spec read_object_from_json_data(Registry.t(), Schema.t(), map()) :: {:ok, any()} | {:error, any()}
  def read_object_from_json_data(%Registry{} = registry, %Schema{} = schema, data) do
    case Object.deserialize(%Reader{decoded: data}, schema, registry) do
      {:ok, %Result{reified: reified}} ->
        {:ok, reified}

      _error ->
        {:error, :deserialization_error}
    end
  end
end
