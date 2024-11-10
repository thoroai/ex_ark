defmodule ExArk.Types do
  @moduledoc """
  Type information
  """
  import UnionTypespec, only: [union_type: 1]

  @primitive_types [
    :bool,
    :uint8,
    :uint16,
    :uint32,
    :uint64,
    :int8,
    :int16,
    :int32,
    :int64,
    :float,
    :double,
    :string,
    :guid,
    :byte_buffer,
    :duration,
    :steady_time_point,
    :system_time_point
  ]
  @enum_types [:enum]
  @complex_types [:array, :arraylist, :dictionary, :object, :variant]
  @all_types @primitive_types ++ @enum_types ++ @complex_types

  union_type primitive_type :: @primitive_types
  union_type enum_type :: @enum_types
  union_type complex_type :: @complex_types
  union_type types :: @all_types

  defguard is_primitive?(type) when type in @primitive_types

  def primitive?(type) when is_binary(type), do: primitive?(String.to_existing_atom(type))
  def primitive?(type) when type in @primitive_types, do: true
  def primitive?(_type), do: false

  def enum?(type) when is_binary(type), do: enum?(String.to_existing_atom(type))
  def enum?(:enum), do: true
  def enum?(_), do: false

  def complex?(type) when is_binary(type), do: complex?(String.to_existing_atom(type))
  def complex?(type), do: !primitive?(type) and !enum?(type)
end
