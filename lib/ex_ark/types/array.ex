defmodule ExArk.Types.Array do
  @moduledoc """
  Module for handling arrays
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result, as: Result
  alias ExArk.Serdes.OutputStream
  alias ExArk.Types

  require Logger

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{array_size: 0} = _field, %Registry{} = _registry),
    do: {:ok, %Result{stream: stream}}

  def read(%InputStream{} = stream, %Field{array_size: size} = field, %Registry{} = registry) do
    reply = {:ok, %Result{stream: stream, reified: []}}

    result =
      Enum.reduce_while(1..size, reply, fn i, {_, result} ->
        case InputStream.read(result.stream, field.ctr_value_type, registry) do
          {:ok, %Result{stream: stream, reified: item}} ->
            {:cont, {:ok, %Result{stream: stream, reified: [item] ++ result.reified}}}

          {:error, _, _, %Result{} = result} = error ->
            Logger.error("Error deserializing array item #{i} (of #{size}): #{inspect(error)}", domain: [:ex_ark])
            {:halt, {:error, :bad_array, nil, result}}
        end
      end)

    with {:ok, %Result{stream: stream, reified: items}} <- result do
      {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
    end
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = stream, %Field{array_size: 0} = _field, _data, %Registry{} = _registry) do
    {:ok, stream}
  end

  def write(%OutputStream{} = stream, %Field{array_size: expected_size} = field, data, %Registry{} = registry)
      when is_list(data) do
    actual_size = length(data)

    if actual_size != expected_size do
      {:error, :array_size_mismatch, %{expected: expected_size, actual: actual_size}, stream}
    else
      write_array_items(stream, field.ctr_value_type, data, registry)
    end
  end

  def write(%OutputStream{} = stream, %Field{} = _field, data, %Registry{} = _registry) do
    {:error, :invalid_array_data, data, stream}
  end

  defp write_array_items(%OutputStream{} = stream, _field_type, [] = _items, _registry) do
    {:ok, stream}
  end

  defp write_array_items(%OutputStream{} = stream, field_type, [item | rest], registry) do
    with {:ok, stream} <- OutputStream.write(stream, field_type, item, registry) do
      write_array_items(stream, field_type, rest, registry)
    end
  end

  @spec default_value(Field.t(), Registry.t()) :: any()
  def default_value(%Field{} = field, %Registry{} = registry) do
    for _ <- 1..field.array_size do
      Types.default_value(field.ctr_value_type, registry)
    end
  end
end
