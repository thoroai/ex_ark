defmodule ExArk.Types do
  @moduledoc """
  Type information
  """

  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.Schema
  alias ExArk.Utilities

  @ark_schema_field :__ark_schema

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
  @complex_types [:array, :arraylist, :dictionary, :object, :variant, :enum]
  @all_types @primitive_types ++ @complex_types

  union_type primitive_type :: @primitive_types
  union_type complex_type :: @complex_types
  union_type types :: @all_types

  @type ark_type :: primitive_type() | complex_type() | String.t()

  @primitive_type_names Enum.map(@primitive_types, &Atom.to_string/1)
  @complex_type_names Enum.map(@complex_types, &Atom.to_string/1)

  @doc """
  Checks if the given type is a primitive type.
  """
  @spec primitive_type?(ark_type()) :: boolean()
  def primitive_type?(type) when is_binary(type), do: type in @primitive_type_names
  def primitive_type?(type) when type in @primitive_types, do: true
  def primitive_type?(_type), do: false

  @doc """
  Checks if the given type is a complex type.
  """
  @spec complex_type?(ark_type()) :: boolean()
  def complex_type?(type) when is_binary(type), do: type in @complex_type_names
  def complex_type?(type) when type in @complex_types, do: true
  def complex_type?(_type), do: false

  @spec default_value(String.t()) :: any()
  def default_value(typestr) when is_binary(typestr), do: default_value(Utilities.ensure_existing_atom(typestr))

  @spec default_value(primitive_type()) :: any()
  def default_value(type)
      when type in [
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
             :steady_time_point,
             :system_time_point
           ],
      do: 0

  def default_value(:byte_buffer), do: <<>>
  def default_value(:guid), do: "00000000-0000-0000-0000-000000000000"
  def default_value(:string), do: ""

  @spec get_type(map()) :: String.t()
  def get_type(data) do
    Map.get(data, @ark_schema_field)
  end

  @spec add_type(map(), Schema.t() | String.t()) :: map()
  def add_type(data, %Schema{} = schema) do
    Map.merge(data, %{@ark_schema_field => Schema.object_name(schema)})
  end

  def add_type(data, object_name) do
    Map.merge(data, %{@ark_schema_field => object_name})
  end
end
