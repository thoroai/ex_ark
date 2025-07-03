defmodule ExArk.Types.Arraylist do
  @moduledoc """
  Module for handling array lists
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OutputStream

  require Logger

  #
  # +----------+--------+--------+-----+--------+
  # | Size (N) | Type 1 | Type 2 | ... | Type N |
  # +----------+--------+--------+-----+--------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(
        %InputStream{bytes: <<0::little-unsigned-integer-size(32), _rest::binary>>} = stream,
        %Field{} = _field,
        %Registry{} = _registry
      ),
      do: {:ok, %Result{stream: InputStream.advance(stream, 4)}}

  def read(
        %InputStream{bytes: <<size::little-unsigned-integer-size(32), _rest::binary>>} = stream,
        %Field{} = field,
        %Registry{} = registry
      ) do
    reply = {:ok, %Result{stream: InputStream.advance(stream, 4), reified: []}}

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

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = stream, %Field{} = _field, [], %Registry{} = _registry),
    # TODO: write 0 explicitly?
    do: {:ok, OutputStream.advance(stream, 4)}

  def write(%OutputStream{} = _stream, %Field{} = _field, _data, %Registry{} = _registry) do
    raise RuntimeError, "Not implemented yet"
  end
end
