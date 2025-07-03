defmodule ExArk.Types.Array do
  @moduledoc """
  Module for handling arrays
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result, as: Result
  alias ExArk.Serdes.OutputStream

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

  @spec write(OutputStream.t(), Field.t(), [any()], Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = stream, %Field{} = _field, [], %Registry{} = _registry), do: {:ok, stream}

  def write(%OutputStream{} = _stream, %Field{} = _field, _data, %Registry{} = _registry) do
    {:error, :not_implemented}
  end
end
