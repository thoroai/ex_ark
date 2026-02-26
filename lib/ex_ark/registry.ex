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
    field :schemas, %{}, default: %{}
    field :enums, %{}, default: %{}
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
  def build_from(%__MODULE__{} = registry, %Schema{} = _schema) do
    # TODO: re-build the registry to include _only_ the needed transitive
    # dependencies, including the top level schema itself. For now, just
    # return the whole registry (which is correct, but potentially terribly
    # inefficient if we loaded all known schemas into it).
    {:ok, registry}
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
    schemas = registry.schemas |> Map.values() |> Enum.map(&Schema.to_map/1)
    enums = registry.enums |> Map.values() |> Enum.map(&ArkEnum.to_map/1)

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
end
