defmodule ExArk.Types.Dictionary do
  @moduledoc """
  Module for handling dictionaries
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  require Logger

  #
  # +----------+-------+---------+-------+---------+-----+-------+---------+
  # | Size (N) | Key 1 | Value 1 | Key 2 | Value 2 | ... | Key N | Value N |
  # +----------+-------+---------+-------+---------+-----+-------+---------+
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
        stream = result.stream

        with {:ok, %Result{stream: stream, reified: key}} <- InputStream.read(stream, field.ctr_key_type, registry),
             {:ok, %Result{stream: stream, reified: value}} <- InputStream.read(stream, field.ctr_value_type, registry) do
          {:cont, {:ok, %Result{stream: stream, reified: [{key, value}] ++ result.reified}}}
        else
          _ ->
            Logger.error(
              "Error deserializing dictionary (key type '#{field.ctr_key_type}', value type '#{field.ctr_value_type}') item #{i}"
            )

            {:halt, {:error, :bad_dictionary}}
        end
      end)

    with {:ok, %Result{stream: stream, reified: items}} <- result do
      {:ok, %Result{stream: stream, reified: Map.new(Enum.reverse(items))}}
    end
  end

  def read(%InputStream{} = _stream, %Field{} = _field, %Registry{} = _registry), do: {:error, :bad_stream}
end
