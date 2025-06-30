defmodule ExArk.Serdes.Json.Fields.Arraylist do
  @moduledoc """
  Module for handling array lists
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
  def read(%Reader{} = reader, %Field{} = field, %Registry{} = registry) do
    reply = {:ok, %ReaderResult{reified: []}}
    original = reader

    result =
      reader.decoded
      |> Enum.with_index(fn elt, idx -> {idx, elt} end)
      |> Enum.reduce_while(reply, fn {i, decoded}, {_, result} ->
        reader = %Reader{decoded: decoded}

        case Fields.read(reader, field.ctr_value_type, registry) do
          {:ok, %ReaderResult{reified: item}} ->
            {:cont, {:ok, %ReaderResult{reified: [item] ++ result.reified}}}

          {:error, name, context, %ReaderResult{} = result} ->
            size = length(original.decoded)

            Logger.error("Error #{inspect(name)} deserializing arraylist item #{i} (of #{size}): #{inspect(context)}",
              domain: [:ex_ark]
            )

            {:halt, {:error, :bad_arraylist, nil, result}}
        end
      end)

    with {:ok, %ReaderResult{reified: items}} <- result do
      {:ok, %ReaderResult{reified: Enum.reverse(items)}}
    end
  end

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{} = field, data, %Registry{} = registry) when is_list(data) do
    # FIXME: we don't really need to pass the writer down. This should be a
    # result type instead, and then remove the writer from the args
    # (throughout all the JSON code).
    case write_array_items(%WriterResult{encoded: []}, field.ctr_value_type, data, registry) do
      {:ok, %WriterResult{encoded: encoded}} ->
        {:ok, %WriterResult{encoded: Enum.reverse(encoded)}}

      error ->
        error
    end
  end

  def write(%Field{} = _field, data, %Registry{} = _registry) do
    {:error, :invalid_array_data, data, %WriterResult{encoded: []}}
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
