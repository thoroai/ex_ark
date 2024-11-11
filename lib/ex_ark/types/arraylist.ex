defmodule ExArk.Types.Arraylist do
  @moduledoc """
  Module for handling array lists
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

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
      do: {:ok, %Result{stream: stream}}

  def read(
        %InputStream{bytes: <<size::little-unsigned-integer-size(32), rest::binary>>, offset: offset} = stream,
        %Field{} = field,
        %Registry{} = registry
      ) do
    stream = %{stream | bytes: rest, offset: offset + 4}

    {stream, items} =
      Enum.reduce(1..size, {stream, []}, fn _i, {stream, items} ->
        {:ok, %Result{stream: stream, reified: item}} = InputStream.read(stream, field.ctr_value_type, registry)
        {stream, [item] ++ items}
      end)

    {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
  end
end
