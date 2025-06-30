defmodule ExArk.Types do
  @moduledoc """
  Type information
  """

  import UnionTypespec, only: [union_type: 1]

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Types.Primitives
  alias ExArk.Utilities

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
      :enum -> ExArk.Types.ArkEnum
    end
  end

  @spec default_value(Field.t() | String.t(), Registry.t()) :: any()
  def default_value(%Field{type: type} = field, %Registry{} = registry) do
    cond do
      primitive_type?(type) ->
        default_field_primitive(type)

      complex_type?(type) ->
        default_field_complex(field, registry)

      true ->
        raise ArgumentError, "Unknown field type: #{inspect(field.type)}"
    end
  end

  defp default_field_primitive(type), do: Primitives.default_value(type)

  defp default_field_complex(%Field{type: type} = field, registry) do
    mod = get_complex_module_for_type(Utilities.ensure_existing_atom(type))
    mod.default_value(field, registry)
  end
end
