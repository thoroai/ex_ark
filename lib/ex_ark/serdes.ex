defmodule ExArk.Serdes do
  @moduledoc false

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Types

  @doc """
  Generates a default value for the given field from the registry.
  """
  @spec default_value(Field.t() | String.t(), Registry.t()) :: any()
  def default_value(%Field{type: type} = field, %Registry{} = registry) do
    cond do
      Types.primitive_type?(type) ->
        Types.default_value(type)

      Types.complex_type?(type) ->
        default_complex(field, registry)

      true ->
        raise ArgumentError, "Unknown field type: #{inspect(field.type)}"
    end
  end

  defp default_complex(%Field{type: "array"} = field, registry) do
    for _ <- 1..field.array_size do
      default_value(field.ctr_value_type, registry)
    end
  end

  defp default_complex(%Field{type: "arraylist"} = _field, _registry), do: []

  defp default_complex(%Field{type: "dictionary"} = _field, _registry), do: %{}

  defp default_complex(%Field{type: "object"} = field, registry) do
    default_object(field.object_type, registry)
  end

  defp default_complex(%Field{type: "variant"} = field, registry) do
    object_type = hd(field.variant_types).object_type
    default_object(object_type, registry)
  end

  defp default_complex(%Field{type: "enum"} = field, registry) do
    enum = registry.enums[field.object_type]

    case enum.enum_type do
      :value ->
        get_default_enum_value(enum.values)

      :bitmask ->
        []
    end
  end

  defp default_object(object_type, %Registry{} = registry) do
    schema = registry.schemas[object_type]

    schema.fields
    |> Enum.map(fn field -> {String.to_atom(field.name), default_value(field, registry)} end)
    |> Map.new()
    |> Types.add_type(schema)
  end

  defp get_default_enum_value([] = _values), do: 0

  defp get_default_enum_value(values) do
    [{_key, value} | _rest] = values
    value
  end
end
