defmodule ExArk.Types.Array do
  @moduledoc """
  Module for handling arrays
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  require Logger

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{array_size: 0} = _field, %Registry{} = _registry),
    do: {:ok, %Result{stream: stream}}

  def read(%InputStream{} = stream, %Field{array_size: size} = field, %Registry{} = registry) do
    reply = {:ok, %Result{stream: stream, reified: []}}

    result =
      Enum.reduce_while(1..size, reply, fn i, {_, result} ->
        case InputStream.read(result.stream, field.ctr_value_type, registry) do
          {:ok, %Result{stream: stream, reified: item}} ->
            {:cont, {:ok, %Result{stream: stream, reified: [item] ++ result.reified}}}

          error ->
            Logger.error("Error deserializing array item #{i} (of #{size}): #{inspect(error)}", domain: [:ex_ark])
            {:halt, {:error, :bad_array}}
        end
      end)

    with {:ok, %Result{stream: stream, reified: items}} <- result do
      {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
    end
  end
end
