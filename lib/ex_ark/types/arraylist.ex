defmodule ExArk.Types.Arraylist do
  @moduledoc """
  Module for handling array lists
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  require Logger

  #
  # +----------+--------+--------+-----+--------+
  # | Size (N) | Type 1 | Type 2 | ... | Type N |
  # +----------+--------+--------+-----+--------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(
        %InputStream{bytes: <<0::little-unsigned-integer-size(32), rest::binary>>, offset: offset} = stream,
        %Field{} = _field,
        %Registry{} = _registry
      ),
      do: {:ok, %Result{stream: %InputStream{stream | bytes: rest, offset: offset + 4}}}

  def read(
        %InputStream{bytes: <<size::little-unsigned-integer-size(32), rest::binary>>, offset: offset} = stream,
        %Field{} = field,
        %Registry{} = registry
      ) do
    stream = %{stream | bytes: rest, offset: offset + 4}

    reply = {:ok, %Result{stream: stream, reified: []}}

    result =
      Enum.reduce_while(1..size, reply, fn i, {_, result} ->
        case InputStream.read(result.stream, field.ctr_value_type, registry) do
          {:ok, %Result{stream: stream, reified: item}} ->
            {:cont, {:ok, %Result{stream: stream, reified: [item] ++ result.reified}}}

          {:error, _, _, %Result{} = result} = error ->
            Logger.error("Error deserializing arraylist item #{i} (of #{size}): #{inspect(error)}", domain: [:ex_ark])
            {:halt, {:error, :bad_arraylist, nil, result}}
        end
      end)

    with {:ok, %Result{stream: stream, reified: items}} <- result do
      {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
    end
  end
end
