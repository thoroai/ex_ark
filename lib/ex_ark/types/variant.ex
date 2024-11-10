defmodule ExArk.Types.Variant do
  @moduledoc """
  Module for handling variants
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{} = _field, %Registry{} = _registry) do
    {:ok, %Result{stream: stream, reified: nil}}
  end
end
