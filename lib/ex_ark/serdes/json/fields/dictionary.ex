defmodule ExArk.Serdes.Json.Fields.Dictionary do
  @moduledoc """
  Module for handling dictionaries
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Fields
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult

  require Logger

  @spec read(Reader.t(), Field.t(), Registry.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(%Reader{decoded: nil} = _reader, %Field{} = _field, %Registry{} = _registry) do
    {:ok, %ReaderResult{reified: %{}}}
  end

  def read(%Reader{} = reader, %Field{} = field, %Registry{} = registry) do
    read_items(reader.decoded, field, registry)
  end

  defp read_items(items, %Field{} = field, %Registry{} = registry) do
    # NOTE: we reify a list here, since we will convert this to a map at the
    # end of the operation.
    reply = {:ok, %ReaderResult{reified: %{}}}

    items
    |> Enum.with_index(fn elt, idx -> {idx, elt} end)
    |> Enum.reduce_while(reply, fn {i, [key, value]}, {_, result} ->
      with {:ok, %ReaderResult{reified: key}} <- Fields.read(%Reader{decoded: key}, field.ctr_key_type, registry),
           {:ok, %ReaderResult{reified: value}} <-
             Fields.read(%Reader{decoded: value}, field.ctr_value_type, registry) do
        {:cont, {:ok, %ReaderResult{reified: Map.put(result.reified, key, value)}}}
      else
        {:error, name, context, %ReaderResult{} = result} ->
          Logger.error(
            "Error #{inspect(name)} deserializing dictionary (key type '#{field.ctr_key_type}', value type '#{field.ctr_value_type}') item #{i}: #{inspect(context)}",
            domain: [:ex_ark]
          )

          {:halt, {:error, :bad_dictionary, nil, result}}
      end
    end)
  end

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{} = field, data, %Registry{} = registry) do
    result =
      Enum.reduce_while(data, {:ok, %WriterResult{encoded: []}}, fn {key, value}, {:ok, result} ->
        acc = result.encoded

        with {:ok, %WriterResult{encoded: key}} <- Fields.write(field.ctr_key_type, key, registry),
             {:ok, %WriterResult{encoded: value}} <- Fields.write(field.ctr_value_type, value, registry) do
          {:cont, {:ok, %WriterResult{result | encoded: [[key, value]] ++ acc}}}
        else
          {:error, name, context} ->
            Logger.error(
              "Error #{inspect(name)} serializing dictionary (key type '#{field.ctr_key_type}', value type '#{field.ctr_value_type}'): item #{context}",
              domain: [:ex_ark]
            )

            {:halt, {:error, :bad_dictionary, nil}}
        end
      end)

    case result do
      {:ok, %WriterResult{encoded: []}} ->
        {:ok, %WriterResult{encoded: nil}}

      {:ok, %WriterResult{encoded: encoded}} ->
        {:ok, %WriterResult{encoded: Enum.reverse(encoded)}}

      other ->
        other
    end
  end
end
