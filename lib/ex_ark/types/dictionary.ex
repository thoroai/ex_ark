defmodule ExArk.Types.Dictionary do
  @moduledoc """
  Module for handling dictionaries
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Serdes.OutputStream

  require Logger

  #
  # +----------+-------+---------+-------+---------+-----+-------+---------+
  # | Size (N) | Key 1 | Value 1 | Key 2 | Value 2 | ... | Key N | Value N |
  # +----------+-------+---------+-------+---------+-----+-------+---------+
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
        stream = result.stream

        with {:ok, %Result{stream: stream, reified: key}} <- InputStream.read(stream, field.ctr_key_type, registry),
             {:ok, %Result{stream: stream, reified: value}} <- InputStream.read(stream, field.ctr_value_type, registry) do
          {:cont, {:ok, %Result{stream: stream, reified: [{key, value}] ++ result.reified}}}
        else
          {:error, _, _, %Result{} = result} ->
            Logger.error(
              "Error deserializing dictionary (key type '#{field.ctr_key_type}', value type '#{field.ctr_value_type}') item #{i}",
              domain: [:ex_ark]
            )

            {:halt, {:error, :bad_dictionary, nil, result}}
        end
      end)

    with {:ok, %Result{stream: stream, reified: items}} <- result do
      {:ok, %Result{stream: stream, reified: Map.new(Enum.reverse(items))}}
    end
  end

  def read(%InputStream{} = _stream, %Field{} = _field, %Registry{} = _registry), do: {:error, :bad_dictionary}

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = _stream, %Field{} = _field, _data, %Registry{} = _registry) do
    raise RuntimeError, "Not implemented yet"
  end
end
