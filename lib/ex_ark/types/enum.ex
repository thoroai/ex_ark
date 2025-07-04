defmodule ExArk.Types.ArkEnum do
  @moduledoc """
  Module for handling enums
  """
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.InputStream.Result, as: Result
  alias ExArk.Serdes.OutputStream
  alias ExArk.Types.Primitives

  require Logger

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, Result.t()} | InputStream.failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    enum = registry.enums[field.object_type]
    {:ok, %Result{stream: stream, reified: value}} = Primitives.read(enum.enum_class, stream)
    # When we read the enum, return the name (key).
    {key, _value} = Enum.find(enum.values, fn {_k, v} -> v == value end)
    {:ok, %Result{stream: stream, reified: key}}
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = stream, %Field{} = field, key, %Registry{} = registry) do
    enum = registry.enums[field.object_type]
    # When we write the enum, we use the value for the key.
    {_key, value} = Enum.find(enum.values, fn {k, _v} -> k == key end)
    Primitives.write(enum.enum_class, value, stream)
  end
end
