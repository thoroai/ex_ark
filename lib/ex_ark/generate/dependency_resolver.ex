defmodule ExArk.Generate.DependencyResolver do
  @moduledoc """
  Resolves the complete set of schemas and enums transitively required by a
  set of top-level schema names.

  If any referenced type is absent from the registry, a descriptive
  `ArgumentError` is raised at call time (i.e. at compile time of the module
  that invokes `use ExArk.Generate`).
  """
  import ExArk.FieldConstants

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry

  @doc """
  Resolves all schemas and enums reachable from the given top-level schema
  names (fully-qualified Ark names, e.g. `"tai::fleet::cloud::PartitionData"`).

  Returns `{schemas, enums}` where both lists are deduplicated and ordered
  depth-first (dependencies before dependents, suitable for ordered module
  definition).

  Raises `ArgumentError` if any referenced schema or enum is absent from the
  registry.
  """
  @spec resolve(Registry.t(), [String.t()]) :: {[Schema.t()], [ArkEnum.t()]}
  def resolve(%Registry{} = registry, top_level_names) do
    {schemas, enums, _seen} =
      Enum.reduce(top_level_names, {[], [], MapSet.new()}, fn name, acc ->
        schema = fetch_schema!(registry, name, "top-level request")
        walk_schema(schema, registry, acc)
      end)

    {Enum.reverse(schemas), Enum.reverse(enums)}
  end

  # Walk a single schema, collecting it and all its transitive deps.
  # Post-order: deps are appended before the schema itself, so that
  # module definitions are emitted in dependency order.
  defp walk_schema(%Schema{} = schema, registry, {schemas, enums, seen}) do
    name = Schema.object_name(schema)

    if MapSet.member?(seen, name) do
      {schemas, enums, seen}
    else
      seen = MapSet.put(seen, name)
      all_fields = schema.fields ++ Enum.flat_map(schema.groups, & &1.fields)

      {schemas, enums, seen} =
        Enum.reduce(all_fields, {schemas, enums, seen}, fn field, acc ->
          walk_field(field, schema, registry, acc)
        end)

      {[schema | schemas], enums, seen}
    end
  end

  defp walk_field(%Field{type: "object", object_type: object_type} = field, parent, registry, acc) do
    schema =
      fetch_schema!(
        registry,
        object_type,
        "field #{inspect(field.name)} in schema #{Schema.object_name(parent)}"
      )

    walk_schema(schema, registry, acc)
  end

  defp walk_field(
         %Field{type: variant(), variant_types: variant_types} = field,
         parent,
         registry,
         acc
       ) do
    Enum.reduce(variant_types, acc, fn variant, acc ->
      schema =
        fetch_schema!(
          registry,
          variant.object_type,
          "variant in field #{inspect(field.name)} in schema #{Schema.object_name(parent)}"
        )

      walk_schema(schema, registry, acc)
    end)
  end

  defp walk_field(
         %Field{type: "enum", object_type: object_type} = field,
         parent,
         registry,
         {schemas, enums, seen}
       ) do
    enum_key = "enum:#{object_type}"

    if MapSet.member?(seen, enum_key) do
      {schemas, enums, seen}
    else
      enum =
        fetch_enum!(
          registry,
          object_type,
          "field #{inspect(field.name)} in schema #{Schema.object_name(parent)}"
        )

      {schemas, [enum | enums], MapSet.put(seen, enum_key)}
    end
  end

  defp walk_field(%Field{type: "array", ctr_value_type: value_type}, parent, registry, acc) do
    walk_field(value_type, parent, registry, acc)
  end

  defp walk_field(%Field{type: "arraylist", ctr_value_type: value_type}, parent, registry, acc) do
    walk_field(value_type, parent, registry, acc)
  end

  defp walk_field(
         %Field{type: "dictionary", ctr_key_type: key_type, ctr_value_type: value_type},
         parent,
         registry,
         acc
       ) do
    acc = walk_field(key_type, parent, registry, acc)
    walk_field(value_type, parent, registry, acc)
  end

  # Primitive types and any unknown field type have no schema/enum deps.
  defp walk_field(_field, _parent, _registry, acc), do: acc

  defp fetch_schema!(registry, name, context) do
    case Map.get(registry.schemas, name) do
      nil ->
        raise ArgumentError,
              "ExArk.Generate: schema #{inspect(name)} (referenced from #{context}) " <>
                "is not present in the registry. The registry must be self-contained " <>
                "and include all transitive dependencies."

      schema ->
        schema
    end
  end

  defp fetch_enum!(registry, name, context) do
    case Map.get(registry.enums, name) do
      nil ->
        raise ArgumentError,
              "ExArk.Generate: enum #{inspect(name)} (referenced from #{context}) " <>
                "is not present in the registry. The registry must be self-contained " <>
                "and include all transitive dependencies."

      enum ->
        enum
    end
  end
end
