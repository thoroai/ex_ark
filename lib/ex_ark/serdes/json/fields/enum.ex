defmodule ExArk.Serdes.Json.Fields.ArkEnum do
  @moduledoc """
  Module for handling enums
  """

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Json
  alias ExArk.Serdes.Json.Fields.Primitives
  alias ExArk.Serdes.Json.Reader
  alias ExArk.Serdes.Json.Reader.Result, as: ReaderResult
  alias ExArk.Serdes.Json.Writer.Result, as: WriterResult

  @spec read(Reader.t(), Field.t(), Registry.t()) :: {:ok, ReaderResult.t()} | Json.deserialization_failure()
  def read(%Reader{} = reader, %Field{} = field, %Registry{} = registry) do
    enum = registry.enums[field.object_type]
    {:ok, %ReaderResult{reified: key}} = Primitives.read(enum.enum_class, reader)
    read_enum(enum, reader, key)
  end

  defp read_enum(%ArkEnum{enum_type: :value} = enum, _reader, key) do
    # When we read the enum, return the name (key).
    {key, _value} = Enum.find(enum.values, fn {k, _v} -> to_string(k) == key end)
    {:ok, %ReaderResult{reified: key}}
  end

  defp read_enum(%ArkEnum{enum_type: :bitmask} = _enum, _reader, keys) do
    # The bitmask keys are sent as a comma separated list in a string
    keys =
      keys
      |> String.split(",")
      |> Enum.map(&String.trim(&1))
      |> Enum.map(&String.to_atom(&1))

    {:ok, %ReaderResult{reified: keys}}
  end

  @spec write(Field.t(), any(), Registry.t()) :: {:ok, WriterResult.t()} | Json.serialization_failure()
  def write(%Field{} = field, key, %Registry{} = registry) do
    enum = registry.enums[field.object_type]
    write_enum(enum, key)
  end

  defp write_enum(%ArkEnum{enum_type: :value} = enum, key) do
    # When we write the enum, we use the key.
    {key, _value} = Enum.find(enum.values, fn {k, _v} -> k == key end)
    Primitives.write(enum.enum_class, key)
  end

  defp write_enum(%ArkEnum{enum_type: :bitmask} = enum, keys) do
    # When we write the enum, we use the bitmask keys, as a comma separated string
    value =
      enum.values
      |> Enum.filter(fn {k, _v} -> Enum.member?(keys, k) end)
      |> Enum.map_join(", ", fn {k, _v} -> k end)

    Primitives.write(enum.enum_class, value)
  end
end
