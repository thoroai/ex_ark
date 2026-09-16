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

  @object_key_types ["string", "guid", "enum"]

  @typep pair :: {term(), term()}
  @typep pairs :: [pair()] | %{term() => term()}
  @typep encoded :: %{optional(term()) => term()} | [[term()]]

  @spec read(Reader.t(), Field.t(), Registry.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(%Reader{decoded: nil} = _reader, %Field{} = _field, %Registry{} = _registry) do
    {:ok, %ReaderResult{reified: %{}}}
  end

  def read(%Reader{} = reader, %Field{} = field, %Registry{} = registry) do
    reader.decoded
    |> to_pairs(field)
    |> read_items(field, registry)
  end

  # Transforms both wire shapes so they enumerate as {key, value}. A decoded object
  # %{"log" => config} already does and is returned untouched, an array of pairs [[1, config]]
  # does not, so it becomes a list of tuples.
  @spec to_pairs(term(), Field.t()) :: pairs()
  defp to_pairs(decoded, %Field{} = field) do
    if encoded_as_object?(field), do: decoded, else: Enum.map(decoded, fn [key, value] -> {key, value} end)
  end

  @spec read_items(pairs(), Field.t(), Registry.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  defp read_items(items, %Field{} = field, %Registry{} = registry) do
    # NOTE: we reify a list here, since we will convert this to a map at the
    # end of the operation.
    reply = {:ok, %ReaderResult{reified: %{}}}

    items
    |> Enum.with_index(fn elt, idx -> {idx, elt} end)
    |> Enum.reduce_while(reply, fn {i, {key, value}}, {_, result} ->
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
      Enum.reduce_while(data, {:ok, %WriterResult{encoded: []}}, fn {key, value}, {:ok, %WriterResult{} = result} ->
        acc = result.encoded

        with {:ok, %WriterResult{encoded: key}} <- Fields.write(field.ctr_key_type, key, registry),
             {:ok, %WriterResult{encoded: value}} <- Fields.write(field.ctr_value_type, value, registry) do
          {:cont, {:ok, %WriterResult{result | encoded: [{key, value}] ++ acc}}}
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
        {:ok, %WriterResult{encoded: encoded |> Enum.reverse() |> from_pairs(field)}}

      other ->
        other
    end
  end

  # Turns the list of {key, value} tuples into a map, or back into a list of [key, value] pairs.
  @spec from_pairs([pair()], Field.t()) :: encoded()
  defp from_pairs(items, %Field{} = field) do
    if encoded_as_object?(field), do: Map.new(items), else: Enum.map(items, fn {key, value} -> [key, value] end)
  end

  # JSON allows only strings as keys. A string, guid or enum key is written as a string, so ark
  # uses it as the key. Any other key, an int or a whole object, cannot be written as a key, so
  # ark writes a list of [key, value] pairs instead. Which one applies is read from the key type
  # the schema declares for this dictionary, `ctr_key_type`.
  @spec encoded_as_object?(Field.t()) :: boolean()
  defp encoded_as_object?(%Field{ctr_key_type: %Field{type: type}}), do: type in @object_key_types
end
