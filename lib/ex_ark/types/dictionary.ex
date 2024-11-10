defmodule ExArk.Types.Dictionary do
  @moduledoc """
  Module for handling dictionaries
  """
  require ExArk.Types
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result
  alias ExArk.Types

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{ctr_key_type: key_type} = field, %Registry{} = registry)
      when Types.is_primitive?(key_type) do
    size = registry[field.array_size]

    {stream, items} =
      Enum.reduce(1..size, {stream, []}, fn _i, {stream, items} ->
        {:ok, %Result{stream: stream, reified: item}} = InputStream.read(stream, field.ctr_value_type, registry)
        {stream, [item] ++ items}
      end)

    {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
  end

  def read(%InputStream{} = _stream, %Field{} = _field, %Registry{} = _registry), do: {:error, :bad_stream}
end
