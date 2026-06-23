defmodule ExArk.Registry do
  @moduledoc """
  Registry for Ark schemas and enums.

  A registry is built by parsing one or more Ark IR (intermediate representation)
  files produced by the Ark compiler. It holds a map of all known schemas
  (`ExArk.Ir.Schema`) and enums (`ExArk.Ir.ArkEnum`), keyed by their
  fully-qualified name (e.g. `"my::Namespace::MySchema"`).

  The preferred way to construct a registry is via `ExArk.load_schemas/1`, which
  reads `.ir` files from disk. For lower-level use, `build/1` accepts the raw
  IR binary content directly.

  ## Fields

    * `:schemas` — map of fully-qualified schema name → `ExArk.Ir.Schema.t()`
    * `:enums` — map of fully-qualified enum name → `ExArk.Ir.ArkEnum.t()`
  """

  use TypedStruct

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Schema

  typedstruct do
    field :schemas, %{optional(String.t()) => Schema.t()}, default: %{}
    field :enums, %{optional(String.t()) => ArkEnum.t()}, default: %{}
  end

  @doc """
  Parse IR binary data and merge the resulting schemas and enums into an existing
  registry.

  Returns `{:error, :duplicate_schema}` or `{:error, :duplicate_enum}` if any
  name in the new data conflicts with a name already in `existing_registry`.
  """
  @spec load(t(), binary()) :: {:ok, any()} | {:error, any()}
  def load(%__MODULE__{} = existing_registry, data) do
    with {:ok, registry} <- build(data) do
      merge(existing_registry, registry)
    end
  end

  @doc """
  Parse IR binary data into a new registry, raising on error.

  Same as `build/1` but returns the registry directly and raises an
  `ArgumentError` if parsing fails.
  """
  @spec build!(binary()) :: t()
  def build!(data) do
    case build(data) do
      {:ok, registry} ->
        registry

      {:error, reason} ->
        raise ArgumentError, "ExArk.Registry.build! failed: #{inspect(reason)}"
    end
  end

  @doc """
  Parse IR binary data into a new registry.

  The `data` argument is the raw content of an `.ir` file (a JSON-encoded
  document). Returns `{:ok, registry}` on success or `{:error, reason}` if the
  data cannot be parsed.
  """
  @spec build(binary()) :: {:ok, any()} | {:error, any()}
  def build(data) do
    with {:ok, decoded} <- JSON.decode(data) do
      decoded
      |> Cldr.Map.atomize_keys()
      |> from_json()
    end
  end

  @doc """
  Build a registry scoped to the transitive dependencies of the given schema.

  Currently returns the full registry unchanged. In a future version this will
  trim the registry to only the schemas and enums transitively required by
  `schema`, which is useful when embedding a minimal registry in a serialized
  object via `ExArk.write_generic_object_to_bytes/3`.
  """
  @spec build_from(t(), Schema.t()) :: {:ok, any()} | {:error, any()}
  def build_from(%__MODULE__{} = registry, %Schema{} = schema) do
    try do
      with {:ok, schema_names, enum_names} <- dependency_closure(registry, [Schema.object_name(schema)]) do
        schemas =
          schema_names
          |> Enum.map(&fetch_schema!(registry, &1))
          |> Map.new(&{Schema.object_name(&1), &1})

        enums =
          enum_names
          |> Enum.map(&fetch_enum!(registry, &1))
          |> Map.new(&{ArkEnum.object_name(&1), &1})

        {:ok, %__MODULE__{schemas: schemas, enums: enums}}
      end
    rescue
      e in ArgumentError ->
        {:error, e.message}
    end
  end

  @doc """
  Build a registry from a decoded JSON term (atom-keyed map).

  The expected shape mirrors the `.ir` file format: a map with `:schemas` and
  `:enums` keys, each containing a list of schema/enum JSON objects.
  """
  @spec from_json(term()) :: {:ok, t()} | {:error, any()}
  def from_json(json) do
    schemas =
      for schema_json <- json.schemas do
        Schema.from_json(schema_json)
      end

    schemas =
      Enum.into(schemas, %{}, fn schema ->
        {Schema.object_name(schema), schema}
      end)

    enums =
      for enum_json <- json.enums do
        ArkEnum.from_json(enum_json)
      end

    enums =
      Enum.into(enums, %{}, fn enum -> {ArkEnum.object_name(enum), enum} end)

    try do
      {:ok, struct(__MODULE__, %{schemas: schemas, enums: enums})}
    rescue
      _error ->
        {:error, :bad_registry}
    end
  end

  @doc """
  Serialize a registry to a JSON binary in the `.ir` file format.

  Returns `{:ok, json_binary}` on success or `{:error, :bad_registry}` if
  encoding fails.
  """
  @spec to_json(t()) :: {:ok, binary()} | {:error, any()}
  def to_json(%__MODULE__{} = registry) do
    schemas =
      registry.schemas
      |> Map.values()
      |> Enum.sort_by(&Schema.object_name/1)
      |> Enum.map(&Schema.to_map/1)

    enums =
      registry.enums
      |> Map.values()
      |> Enum.sort_by(&ArkEnum.object_name/1)
      |> Enum.map(&ArkEnum.to_map/1)

    result =
      %{"schemas" => schemas, "enums" => enums}
      |> JSON.encode!()

    {:ok, result}
  rescue
    _error ->
      {:error, :bad_registry}
  end

  defp merge(registry, new) do
    cond do
      duplicate?(registry.schemas, new.schemas) ->
        {:error, :duplicate_schema}

      duplicate?(registry.enums, new.enums) ->
        {:error, :duplicate_enum}

      true ->
        {:ok,
         %{
           registry
           | schemas: Map.merge(registry.schemas, new.schemas),
             enums: Map.merge(registry.enums, new.enums)
         }}
    end
  end

  defp duplicate?(a, b), do: !Enum.empty?(Map.intersect(a, b))

  defp dependency_closure(%__MODULE__{} = registry, root_schema_names) do
    walk_queue(root_schema_names, registry, MapSet.new(), MapSet.new(), MapSet.new())
  end

  defp walk_queue([], _registry, _seen_schemas, seen_enums, order_schemas) do
    {:ok, MapSet.to_list(order_schemas), MapSet.to_list(seen_enums)}
  end

  defp walk_queue([schema_name | rest], registry, seen_schemas, seen_enums, order_schemas) do
    cond do
      MapSet.member?(seen_schemas, schema_name) ->
        walk_queue(rest, registry, seen_schemas, seen_enums, order_schemas)

      true ->
        schema = fetch_schema!(registry, schema_name)
        {schema_deps, enum_deps} = schema_dependencies(schema)

        seen_schemas = MapSet.put(seen_schemas, schema_name)
        order_schemas = MapSet.put(order_schemas, schema_name)
        seen_enums = Enum.reduce(enum_deps, seen_enums, &MapSet.put(&2, &1))
        queue = Enum.reduce(schema_deps, rest, fn dep, acc -> [dep | acc] end)

        walk_queue(queue, registry, seen_schemas, seen_enums, order_schemas)
    end
  end

  defp schema_dependencies(%Schema{} = schema) do
    schema.fields
    |> Kernel.++(Enum.flat_map(schema.groups, & &1.fields))
    |> Enum.reduce({MapSet.new(), MapSet.new()}, fn field, {schemas, enums} ->
      collect_field_dependencies(field, schemas, enums)
    end)
    |> then(fn {schemas, enums} -> {MapSet.to_list(schemas), MapSet.to_list(enums)} end)
  end

  defp collect_field_dependencies(%ExArk.Ir.Field{type: "object", object_type: object_type}, schemas, enums) do
    {MapSet.put(schemas, object_type), enums}
  end

  defp collect_field_dependencies(%ExArk.Ir.Field{type: "enum", object_type: object_type}, schemas, enums) do
    {schemas, MapSet.put(enums, object_type)}
  end

  defp collect_field_dependencies(%ExArk.Ir.Field{type: "variant", variant_types: variants}, schemas, enums) do
    Enum.reduce(variants, {schemas, enums}, fn variant, {schemas, enums} ->
      {MapSet.put(schemas, variant.object_type), enums}
    end)
  end

  defp collect_field_dependencies(%ExArk.Ir.Field{type: "array", ctr_value_type: ctr_value_type}, schemas, enums) do
    collect_field_dependencies(ctr_value_type, schemas, enums)
  end

  defp collect_field_dependencies(%ExArk.Ir.Field{type: "arraylist", ctr_value_type: ctr_value_type}, schemas, enums) do
    collect_field_dependencies(ctr_value_type, schemas, enums)
  end

  defp collect_field_dependencies(%ExArk.Ir.Field{type: "dictionary", ctr_key_type: ctr_key_type, ctr_value_type: ctr_value_type}, schemas, enums) do
    {schemas, enums} = collect_field_dependencies(ctr_key_type, schemas, enums)
    collect_field_dependencies(ctr_value_type, schemas, enums)
  end

  defp collect_field_dependencies(%ExArk.Ir.Field{}, schemas, enums), do: {schemas, enums}

  defp fetch_schema!(%__MODULE__{} = registry, name) do
    case Map.fetch(registry.schemas, name) do
      {:ok, schema} -> schema
      :error -> raise ArgumentError, "missing schema dependency: #{inspect(name)}"
    end
  end

  defp fetch_enum!(%__MODULE__{} = registry, name) do
    case Map.fetch(registry.enums, name) do
      {:ok, enum} -> enum
      :error -> raise ArgumentError, "missing enum dependency: #{inspect(name)}"
    end
  end
end
