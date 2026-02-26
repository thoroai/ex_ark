defmodule ExArk.Generate.TypeSpec do
  @moduledoc """
  Generates Elixir typespec AST nodes for Ark field types.

  All public functions return quoted Elixir expressions suitable for embedding
  in `typedstruct` field declarations or `@type` attributes.

  Raises `ArgumentError` at call time (i.e. compile time of the module using
  `ExArk.Generate`) if a referenced schema or enum is absent from the registry.
  """

  alias ExArk.Generate.Naming
  alias ExArk.Ir.Field
  alias ExArk.Registry

  @primitive_integers ~w[uint8 uint16 uint32 uint64]
  @signed_integers ~w[int8 int16 int32 int64]
  @floats ~w[float double]
  @time_types ~w[duration steady_time_point system_time_point]

  @doc """
  Returns the Elixir typespec AST for a field.

  Options:
  - `nullable: true` — wraps the base type in `typespec() | nil`. Use for
    optional fields and group fields (which may be absent).
  """
  @spec for_field(Field.t(), Registry.t(), module(), keyword()) :: Macro.t()
  def for_field(%Field{} = field, %Registry{} = registry, namespace, opts \\ []) do
    nullable = Keyword.get(opts, :nullable, false)
    base = base_type(field, registry, namespace)

    if nullable do
      quote do: unquote(base) | nil
    else
      base
    end
  end

  # ---------------------------------------------------------------------------
  # Base type derivation
  # ---------------------------------------------------------------------------

  defp base_type(%Field{type: "bool"}, _registry, _namespace) do
    quote do: boolean()
  end

  defp base_type(%Field{type: "string"}, _registry, _namespace) do
    quote do: String.t()
  end

  defp base_type(%Field{type: "guid"}, _registry, _namespace) do
    quote do: String.t()
  end

  defp base_type(%Field{type: "byte_buffer"}, _registry, _namespace) do
    quote do: binary()
  end

  defp base_type(%Field{type: t}, _registry, _namespace) when t in @primitive_integers do
    quote do: non_neg_integer()
  end

  defp base_type(%Field{type: t}, _registry, _namespace) when t in @signed_integers do
    quote do: integer()
  end

  defp base_type(%Field{type: t}, _registry, _namespace) when t in @floats do
    quote do: float()
  end

  defp base_type(%Field{type: t}, _registry, _namespace) when t in @time_types do
    quote do: integer()
  end

  defp base_type(%Field{type: "enum", object_type: object_type} = field, registry, _namespace) do
    unless Map.has_key?(registry.enums, object_type) do
      raise ArgumentError,
            "ExArk.Generate: enum type #{inspect(object_type)} for field " <>
              "#{inspect(field.name)} is not present in the registry."
    end

    quote do: atom()
  end

  defp base_type(%Field{type: "object", object_type: object_type} = field, registry, namespace) do
    unless Map.has_key?(registry.schemas, object_type) do
      raise ArgumentError,
            "ExArk.Generate: object type #{inspect(object_type)} for field " <>
              "#{inspect(field.name)} is not present in the registry."
    end

    mod = Naming.ark_name_to_module(object_type, namespace)
    quote do: unquote(mod).t()
  end

  defp base_type(
         %Field{type: "variant", variant_types: variants} = field,
         registry,
         namespace
       ) do
    Enum.each(variants, fn variant ->
      unless Map.has_key?(registry.schemas, variant.object_type) do
        raise ArgumentError,
              "ExArk.Generate: variant type #{inspect(variant.object_type)} in field " <>
                "#{inspect(field.name)} is not present in the registry."
      end
    end)

    [first | rest] =
      Enum.map(variants, fn variant ->
        mod = Naming.ark_name_to_module(variant.object_type, namespace)
        quote do: unquote(mod).t()
      end)

    Enum.reduce(rest, first, fn type, acc ->
      quote do: unquote(acc) | unquote(type)
    end)
  end

  defp base_type(%Field{type: "array", ctr_value_type: value_type}, registry, namespace) do
    elem = base_type(value_type, registry, namespace)
    quote do: [unquote(elem)]
  end

  defp base_type(%Field{type: "arraylist", ctr_value_type: value_type}, registry, namespace) do
    elem = base_type(value_type, registry, namespace)
    quote do: [unquote(elem)]
  end

  defp base_type(
         %Field{type: "dictionary", ctr_key_type: key_type, ctr_value_type: value_type},
         registry,
         namespace
       ) do
    key = base_type(key_type, registry, namespace)
    val = base_type(value_type, registry, namespace)
    quote do: %{optional(unquote(key)) => unquote(val)}
  end
end
