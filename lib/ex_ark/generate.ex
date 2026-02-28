defmodule ExArk.Generate do
  @moduledoc """
  Compile-time code generation for Ark schemas.

  Add `use ExArk.Generate` to a module to generate typed Elixir structs and
  serialization helpers for a set of Ark schemas at compile time.

  ## Options

  - `registry:` (**required**) – path to a `registry.json` file, relative to
    the Mix project root. The file is read at compile time; an error is raised
    if it is absent or malformed.

  - `namespace:` (**required**) – Elixir module atom prepended to every
    generated module name. Example: `namespace: MyApp.Ark` yields modules
    like `MyApp.Ark.Tai.Fleet.Cloud.RobotStatus`.

  - `schemas:` (optional) – list of fully-qualified Ark schema names to
    generate, e.g. `["tai::fleet::cloud::PartitionData"]`. All transitively
    required schemas and enums are generated automatically. If omitted, all
    schemas in the registry are generated and a compile-time warning is
    emitted to encourage explicit filtering.

  ## Example

      defmodule MyApp.ArkSchemas do
        use ExArk.Generate,
          registry: "priv/registry.json",
          namespace: MyApp.Ark,
          schemas: [
            "tai::fleet::cloud::PartitionData",
            "tai::fleet::cloud::PostFleetManagementNotification"
          ]
      end

  ## Generated module contract

  For each schema a module is defined with:

  - A struct with typed fields (required fields are enforced; optional and
    group fields default to `nil`)
  - `serialize_to_binary/1` -> `{:ok, binary()} | {:error, any()}`
  - `serialize_to_json/1` -> `{:ok, String.t()} | {:error, any()}`
  - `deserialize_from_binary/1` -> `{:ok, t()} | {:error, any()}`
  - `deserialize_from_json/1` -> `{:ok, t()} | {:error, any()}`
  - `__ark_schema_name/0` — returns the fully-qualified Ark schema name string
  - `to_map/1` / `from_map/1` — `@doc false` public helpers for nested
    struct <-> map conversion

  For each enum a module is defined with:

  - `@type t` — union type of all value atoms
  - `values/0` — returns all value atoms in declaration order

  ## Resolving a module from a schema name

  When a schema name arrives at runtime (e.g. from an MQTT message's `schema`
  field), use `module_for/2` to obtain the corresponding generated module and
  then dispatch to its deserialize functions:

      {:ok, mod} = ExArk.Generate.module_for(schema_name, MyApp.Ark)
      {:ok, struct} = mod.deserialize_from_json(payload)

      # or, raising on unknown schema:
      mod = ExArk.Generate.module_for!(schema_name, MyApp.Ark)
      {:ok, struct} = mod.deserialize_from_binary(payload)

  """

  alias ExArk.Generate.DependencyResolver
  alias ExArk.Generate.EnumBuilder
  alias ExArk.Generate.Naming
  alias ExArk.Generate.SchemaBuilder
  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Schema
  alias ExArk.Registry

  @doc """
  Returns the generated module for the given Ark schema name and namespace.

  The module is identified by computing its expected name via the same
  `ExArk.Generate.Naming` rules used at code-generation time, then verifying
  that the module is loaded and is an ExArk-generated schema module (i.e. it
  exports `__ark_schema_name/0`).

  Returns `{:error, :not_found}` if no matching generated module exists.

  ## Examples

      iex> ExArk.Generate.module_for("tai::fleet::cloud::RobotStatus", MyApp.Ark)
      {:ok, MyApp.Ark.Tai.Fleet.Cloud.RobotStatus}

      iex> ExArk.Generate.module_for("unknown::Schema", MyApp.Ark)
      {:error, :not_found}

  """
  @spec module_for(String.t(), module()) :: {:ok, module()} | {:error, :not_found}
  def module_for(ark_name, namespace) when is_binary(ark_name) and is_atom(namespace) do
    mod = Naming.ark_name_to_module(ark_name, namespace)

    case Code.ensure_loaded(mod) do
      {:module, ^mod} ->
        if function_exported?(mod, :__ark_schema_name, 0) do
          {:ok, mod}
        else
          {:error, :not_found}
        end

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns the generated module for the given Ark schema name and namespace,
  raising if no matching module is found.

  Same as `module_for/2` but returns the module directly and raises
  `ArgumentError` on failure.

  ## Examples

      iex> ExArk.Generate.module_for!("tai::fleet::cloud::RobotStatus", MyApp.Ark)
      MyApp.Ark.Tai.Fleet.Cloud.RobotStatus

  """
  @spec module_for!(String.t(), module()) :: module()
  def module_for!(ark_name, namespace) when is_binary(ark_name) and is_atom(namespace) do
    case module_for(ark_name, namespace) do
      {:ok, mod} ->
        mod

      {:error, :not_found} ->
        raise ArgumentError,
              "ExArk.Generate: no generated module found for Ark schema " <>
                inspect(ark_name) <> " under namespace #{inspect(namespace)}"
    end
  end

  defmacro __using__(opts) do
    registry_path = Keyword.fetch!(opts, :registry)

    namespace =
      case Keyword.fetch(opts, :namespace) do
        {:ok, ns} ->
          Macro.expand(ns, __CALLER__)

        :error ->
          raise ArgumentError,
                "ExArk.Generate requires a `namespace:` option. " <>
                  "Example: `use ExArk.Generate, namespace: MyApp.Ark, registry: \"...\"`"
      end

    schema_filter = Keyword.get(opts, :schemas, :all)

    # Warn when no schema filter is supplied.
    if schema_filter == :all do
      IO.warn(
        "ExArk.Generate called without a `schemas:` filter — all schemas in " <>
          inspect(registry_path) <>
          " will be generated. " <>
          "Specify `schemas:` to limit generation to the types your application uses.",
        __CALLER__
      )
    end

    # Read and parse the registry at compile time.
    registry =
      registry_path
      |> File.read!()
      |> Registry.build!()

    # Resolve the set of top-level schemas to generate.
    top_level_names =
      case schema_filter do
        :all -> Map.keys(registry.schemas)
        names -> validate_schema_names!(registry, names)
      end

    # Resolve all transitive deps.
    {all_schemas, all_enums} = DependencyResolver.resolve(registry, top_level_names)

    # Build a sub-registry containing only the schemas and enums we need.
    sub_registry = %Registry{
      schemas: Map.take(registry.schemas, Enum.map(all_schemas, &Schema.object_name/1)),
      enums: Map.take(registry.enums, Enum.map(all_enums, &ArkEnum.object_name/1))
    }

    {:ok, sub_registry_json} = Registry.to_json(sub_registry)

    # Generate enum modules first (they have no deps on schema modules).
    enum_asts =
      Enum.map(all_enums, fn enum ->
        EnumBuilder.build(enum, namespace)
      end)

    # Generate schema modules (deps-first order from DependencyResolver).
    schema_asts =
      Enum.map(all_schemas, fn schema ->
        SchemaBuilder.build(schema, registry, namespace, sub_registry_json)
      end)

    quote do
      unquote_splicing(enum_asts)
      unquote_splicing(schema_asts)
    end
  end

  defp validate_schema_names!(registry, names) do
    Enum.each(names, fn name ->
      unless Map.has_key?(registry.schemas, name) do
        raise ArgumentError,
              "ExArk.Generate: schema #{inspect(name)} is not present in the registry. " <>
                "Available schemas: #{inspect(Map.keys(registry.schemas))}"
      end
    end)

    names
  end
end
