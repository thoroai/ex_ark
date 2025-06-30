defmodule ExArk.Serdes.Binary.Fields.ArkEnum do
  @moduledoc """
  Module for handling enums
  """

  import Bitwise

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.OutputStream

  @spec read(InputStream.t(), Field.t(), Registry.t()) :: {:ok, Result.t()} | Binary.deserialization_failure()
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

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) ::
          {:ok, OutputStream.t()} | Binary.serialization_failure()
  def write(%OutputStream{} = stream, %Field{} = field, key, %Registry{} = registry) do
    enum = registry.enums[field.object_type]
    write_enum(enum, stream, key)
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
