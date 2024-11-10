defmodule ExArk.Types.Dictionary do
  @moduledoc """
  Module for handling dictionaries
  """
  require ExArk.Types
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  #
  # +----------+-------+---------+-------+---------+-----+-------+---------+
  # | Size (N) | Key 1 | Value 1 | Key 2 | Value 2 | ... | Key N | Value N |
  # +----------+-------+---------+-------+---------+-----+-------+---------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(
        %InputStream{bytes: <<size::little-unsigned-integer-size(32), rest::binary>>, offset: offset} = stream,
        %Field{} = field,
        %Registry{} = registry
      ) do
    stream = %{stream | bytes: rest, offset: offset + 4}

    {stream, items} =
      Enum.reduce(1..size, {stream, []}, fn _i, {stream, items} ->
        with {:ok, %Result{stream: stream, reified: key}} <- InputStream.read(stream, field.ctr_key_type, registry),
             {:ok, %Result{stream: stream, reified: value}} <- InputStream.read(stream, field.ctr_value_type, registry) do
          {stream, [{key, value}] ++ items}
        end
      end)

    {:ok, %Result{stream: stream, reified: Map.new(Enum.reverse(items))}}
  end

  def read(%InputStream{} = _stream, %Field{} = _field, %Registry{} = _registry), do: {:error, :bad_stream}
end
