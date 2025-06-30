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

  @type ark_type :: primitive_type() | enum_type() | complex_type() | String.t()

  @enum_type_names Enum.map(@enum_types, &Atom.to_string/1)
  @primitive_type_names Enum.map(@primitive_types, &Atom.to_string/1)

  @doc """
  Checks if the given type is a primitive type.
  """
  @spec primitive_type?(ark_type()) :: boolean()
  def primitive_type?(type) when is_binary(type), do: type in @primitive_type_names
  def primitive_type?(type) when type in @primitive_types, do: true
  def primitive_type?(_type), do: false

  @doc """
  Checks if the given type is an enum type.
  """
  @spec enum_type?(ark_type()) :: boolean()
  def enum_type?(type) when is_binary(type), do: type in @enum_type_names
  def enum_type?(:enum), do: true
  def enum_type?(_), do: false

  @doc """
  Checks if the given type is a complex type.
  """
  @spec complex_type?(ark_type()) :: boolean()
  def complex_type?(type) when is_binary(type), do: complex_type?(String.to_existing_atom(type))
  def complex_type?(type), do: !primitive_type?(type) and !enum_type?(type)

  @doc """
  Gets the module responsible for handling the given complex type.
  """
  def get_complex_module_for_type(type) when type in @complex_types do
    case type do
      :array -> ExArk.Types.Array
      :arraylist -> ExArk.Types.Arraylist
      :dictionary -> ExArk.Types.Dictionary
      :object -> ExArk.Types.Object
      :variant -> ExArk.Types.Variant
    end
  end
end
