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

  def read(%Reader{decoded: decoded}, %Field{} = field, %Registry{} = registry) do
    case decoded_items(decoded, field) do
      {:ok, items} -> read_items(items, field, registry)
      {:error, context} -> {:error, :bad_dictionary, context, %ReaderResult{reified: %{}}}
    end
  end

  # JSON objects already enumerate as {key, value}. Pair arrays are canonical
  # for other key types, and are also accepted for string-like keys so payloads
  # written by older ex_ark versions remain readable.
  defp decoded_items(decoded, field) when is_map(decoded) do
    if object_key?(field.ctr_key_type), do: {:ok, Map.to_list(decoded)}, else: {:error, decoded}
  end

  defp decoded_items(decoded, _field) when is_list(decoded) do
    Enum.reduce_while(decoded, {:ok, []}, fn
      [key, value], {:ok, items} -> {:cont, {:ok, [{key, value} | items]}}
      item, _acc -> {:halt, {:error, item}}
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp decoded_items(decoded, _field), do: {:error, decoded}

  defp read_items(items, %Field{} = field, %Registry{} = registry) do
    reply = {:ok, %ReaderResult{reified: %{}}}

    items
    |> Enum.with_index()
    |> Enum.reduce_while(reply, fn {{key, value}, i}, {_, result} ->
      read_item(key, value, i, field, registry, result)
    end)
  end

  defp read_item(key, value, index, field, registry, result) do
    with {:ok, %ReaderResult{reified: key}} <-
           Fields.read(%Reader{decoded: key}, field.ctr_key_type, registry),
         {:ok, %ReaderResult{reified: value}} <-
           Fields.read(%Reader{decoded: value}, field.ctr_value_type, registry) do
      {:cont, {:ok, %ReaderResult{reified: Map.put(result.reified, key, value)}}}
    else
      {:error, name, context, %ReaderResult{}} ->
        log_read_error(name, context, index, field)
        {:halt, {:error, :bad_dictionary, context, result}}

      error ->
        log_read_error(:bad_dictionary_item, error, index, field)
        {:halt, {:error, :bad_dictionary, error, result}}
    end
  end

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{} = field, data, %Registry{} = registry) do
    with {:ok, items} <- encode_items(data, field, registry) do
      {:ok, %WriterResult{encoded: encode_container(items, field)}}
    end
  end

  defp encode_container(items, field) do
    if object_key?(field.ctr_key_type) do
      Map.new(items, fn {key, value} -> {to_string(key), value} end)
    else
      Enum.map(items, fn {key, value} -> [key, value] end)
    end
  end

  defp encode_items(data, %Field{} = field, %Registry{} = registry) do
    data
    |> Enum.reduce_while({:ok, []}, fn {key, value}, {:ok, items} ->
      with {:ok, %WriterResult{encoded: key}} <- Fields.write(field.ctr_key_type, key, registry),
           {:ok, %WriterResult{encoded: value}} <- Fields.write(field.ctr_value_type, value, registry) do
        {:cont, {:ok, [{key, value} | items]}}
      else
        {:error, name, context} ->
          log_write_error(name, context, field)
          {:halt, {:error, :bad_dictionary, context}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp object_key?(%Field{type: type}) when type in ["string", "guid", "enum"], do: true
  defp object_key?(_field), do: false

  defp log_read_error(name, context, index, field) do
    Logger.error(
      "Error #{inspect(name)} deserializing dictionary (key type '#{inspect(field.ctr_key_type)}', value type '#{inspect(field.ctr_value_type)}') item #{index}: #{inspect(context)}",
      domain: [:ex_ark]
    )
  end

  defp log_write_error(name, context, field) do
    Logger.error(
      "Error #{inspect(name)} serializing dictionary (key type '#{inspect(field.ctr_key_type)}', value type '#{inspect(field.ctr_value_type)}'): item #{inspect(context)}",
      domain: [:ex_ark]
    )
  end
end
