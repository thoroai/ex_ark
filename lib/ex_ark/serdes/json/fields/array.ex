defmodule ExArk.Serdes.Json.Fields.Array do
  @moduledoc """
  Module for handling arrays
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
  def read(%Reader{} = _reader, %Field{array_size: 0} = _field, %Registry{} = _registry),
    do: {:ok, %ReaderResult{}}

  def read(%Reader{} = reader, %Field{array_size: size} = field, %Registry{} = registry) do
    actual_size = length(reader.decoded)

    if length(reader.decoded) != size do
      Logger.error("Error deserializing array (of #{size}): size #{inspect(actual_size)}", domain: [:ex_ark])
      {:error, :bad_array, {size, actual_size}, %ReaderResult{reified: []}}
    else
      read_items(reader, field, registry)
    end
  end

  defp read_items(%Reader{} = reader, %Field{array_size: size} = field, %Registry{} = registry) do
    reply = {:ok, %ReaderResult{reified: []}}

    result =
      reader.decoded
      |> Enum.with_index(fn elt, idx -> {idx, elt} end)
      |> Enum.reduce_while(reply, fn {i, decoded}, {_, result} ->
        reader = %Reader{decoded: decoded}

        case Fields.read(reader, field.ctr_value_type, registry) do
          {:ok, %ReaderResult{reified: item}} ->
            {:cont, {:ok, %ReaderResult{reified: [item] ++ result.reified}}}

          {:error, _, _, %ReaderResult{} = result} = error ->
            Logger.error("Error deserializing array item #{i} (of #{size}): #{inspect(error)}", domain: [:ex_ark])
            {:halt, {:error, :bad_array, nil, result}}
        end
      end)

    with {:ok, %ReaderResult{reified: items}} <- result do
      {:ok, %ReaderResult{reified: Enum.reverse(items)}}
    end
  end

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{array_size: 0} = _field, _data, %Registry{} = _registry) do
    {:ok, %WriterResult{encoded: []}}
  end

  def write(%Field{array_size: expected_size} = field, data, %Registry{} = registry) when is_list(data) do
    actual_size = length(data)

    if actual_size != expected_size do
      {:error, :array_size_mismatch, %{expected: expected_size, actual: actual_size}}
    else
      # TODO: we don't really need to pass the writer down. This should be a
      # result type instead, and then remove the writer from the args
      # (throughout all the JSON code).
      case write_array_items(%WriterResult{encoded: []}, field.ctr_value_type, data, registry) do
        {:ok, %WriterResult{encoded: encoded}} ->
          {:ok, %WriterResult{encoded: Enum.reverse(encoded)}}

        error ->
          error
      end
    end
  end

  def write(%Field{} = _field, data, %Registry{} = _registry) do
    {:error, :invalid_array_data, data}
  end

  defp write_array_items(%WriterResult{} = result, _field, [] = _items, _registry) do
    {:ok, result}
  end

  defp write_array_items(%WriterResult{encoded: acc} = _result, field, [item | rest], registry) do
    with {:ok, %WriterResult{encoded: encoded} = result} <- Fields.write(field, item, registry) do
      write_array_items(%WriterResult{result | encoded: [encoded | acc]}, field, rest, registry)
    end
  end
end
