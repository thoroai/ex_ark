defmodule ExArk.Types.ArkEnum do
  @moduledoc """
  Module for handling enums
  """

  import Bitwise

  alias ExArk.Ir.ArkEnum
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
    read_enum(enum, stream, value)
  end

  defp read_enum(%ArkEnum{enum_type: :value} = enum, stream, value) do
    # When we read the enum, return the name (key).
    {key, _value} = Enum.find(enum.values, fn {_k, v} -> v == value end)
    {:ok, %Result{stream: stream, reified: key}}
  end

  defp read_enum(%ArkEnum{enum_type: :bitmask} = enum, stream, value) do
    # When we read the enum, return the bitfield names (keys) that apply.
    keys = Enum.flat_map(enum.values, fn {k, v} -> if (v &&& value) != 0, do: [k], else: [] end)
    {:ok, %Result{stream: stream, reified: keys}}
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) :: {:ok, OutputStream.t()} | OutputStream.failure()
  def write(%OutputStream{} = stream, %Field{} = field, key, %Registry{} = registry) do
    enum = registry.enums[field.object_type]
    write_enum(enum, stream, key)
  end

  @spec default_value(Field.t(), Registry.t()) :: any()
  def default_value(%Field{} = field, %Registry{} = registry) do
    # The default value is used in constructing an "empty" object for
    # serialization, so get the first value.
    enum = registry.enums[field.object_type]

    case enum.enum_type do
      :value ->
        [{_key, value} | _rest] = enum.values
        value

      :bitmask ->
        []
    end
  end

  defp write_enum(%ArkEnum{enum_type: :value} = enum, stream, key) do
    # When we write the enum, we use the value for the key.
    {_key, value} = Enum.find(enum.values, fn {k, _v} -> k == key end)
    Primitives.write(enum.enum_class, value, stream)
  end

  defp write_enum(%ArkEnum{enum_type: :bitmask} = enum, stream, keys) do
    # When we write the enum, we use the bitmask value for the keys.
    value = Enum.reduce(enum.values, 0, fn {k, v}, acc -> if Enum.member?(keys, k), do: acc ||| v, else: acc end)
    Primitives.write(enum.enum_class, value, stream)
  end
end
