defmodule ExArk.Types.Array do
  @moduledoc """
  Module for handling arrays
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    size = registry[field.array_size]

    {stream, items} =
      Enum.reduce(1..size, {stream, []}, fn _i, {stream, items} ->
        {:ok, %Result{stream: stream, reified: item}} = InputStream.read(stream, field.ctr_value_type, registry)
        {stream, [item] ++ items}
      end)

    {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
  end
end
