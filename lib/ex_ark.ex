defmodule ExArk do
  @moduledoc """
  Elixir library for serializing and deserializing Ark serialized objects.

  [Ark](https://ark.tbdrobotics.com) is a robotics toolkit that includes a serialization
  library with a custom IDL for structured data objects. ExArk provides the tooling to load
  Ark IR (intermediate representation) schema files and to serialize and deserialize Ark
  objects in both binary and JSON formats.

  There are two ways to work with Ark objects in Elixir:

  1. **Compile-time generated modules** (preferred) — `ExArk.Generate` reads a registry JSON
     file at compile time and generates typed Elixir structs with built-in serialize/deserialize
     functions. This gives you full type safety, struct field access, and no runtime registry
     dependency.

  2. **Generic map-based API** (this module) — schemas are loaded at runtime from `.ir` files
     and objects are represented as atom-keyed maps. Useful when the schema is not known at
     compile time, or for self-describing binary data that embeds its own schema.

  ## Compile-Time Code Generation

  Point `ExArk.Generate` at a `registry.json` file (exported from the Ark compiler) and
  declare which schemas your application needs:

      defmodule MyApp.ArkSchemas do
        use ExArk.Generate,
          registry: "priv/registry.json",
          namespace: MyApp.Ark,
          schemas: [
            "my::namespace::Point",
            "my::namespace::Pose"
          ]
      end

  This generates a module per schema (e.g. `MyApp.Ark.MyNamespace.Point`) with a typed
  struct and serialize/deserialize functions:

      # Serialize
      point = %MyApp.Ark.MyNamespace.Point{x: 1.0, y: 2.0}
      {:ok, bytes} = MyApp.Ark.MyNamespace.Point.serialize_to_binary(point)
      {:ok, json}  = MyApp.Ark.MyNamespace.Point.serialize_to_json(point)

      # Deserialize
      {:ok, point} = MyApp.Ark.MyNamespace.Point.deserialize_from_binary(bytes)
      {:ok, point} = MyApp.Ark.MyNamespace.Point.deserialize_from_json(json)

  See `ExArk.Generate` for the full option reference and generated module contract.

  ## Generic Map-Based API

  Load one or more `.ir` schema files into a registry at runtime:

      {:ok, registry} = ExArk.load_schemas("/path/to/my.ir")

  Then read and write objects using the fully-qualified Ark type name as a string:

      {:ok, object} = ExArk.read_object_from_bytes(registry, "my::namespace::Point", bytes)
      {:ok, object} = ExArk.read_object_from_json(registry, "my::namespace::Point", json_string)

      {:ok, bytes} = ExArk.write_object_to_bytes(registry, "my::namespace::Point", object)
      {:ok, json}  = ExArk.write_object_to_json(registry, "my::namespace::Point", object)

  Objects are returned as **atom-keyed maps**, e.g. `%{x: 1.0, y: 2.0}`.

  When the binary data is self-describing (schema embedded in the payload), no registry or
  type name is needed:

      {:ok, object} = ExArk.read_generic_object_from_bytes(bytes)
      {:ok, object} = ExArk.read_generic_object_from_file("/path/to/data.bin")

  ### Variant fields

  Variant fields in map-based objects carry a `:__ark_schema` key that identifies the
  concrete type at runtime. Use `ExArk.Types.get_type/1` to read it and
  `ExArk.Types.add_type/2` to set it when constructing objects for serialization.

  ## Schema Registry

  `ExArk.Registry` holds all loaded schemas (`ExArk.Ir.Schema`) and enums
  (`ExArk.Ir.ArkEnum`), keyed by their fully-qualified name (e.g.
  `"my::namespace::Point"`). Multiple `.ir` files can be combined into a single registry by
  passing a list of paths to `load_schemas/1`.

  ## Modules

  | Module | Purpose |
  |---|---|
  | `ExArk.Generate` | Compile-time code generation of typed structs from a registry |
  | `ExArk.Registry` | Runtime registry of Ark schemas and enums loaded from `.ir` files |
  | `ExArk.Types` | Type predicates, default value generation, and variant tagging |
  | `ExArk.Ir.Schema` | IR representation of a schema definition |
  | `ExArk.Ir.ArkEnum` | IR representation of an enum definition |
  | `ExArk.Ir.Field` | IR representation of a schema field |
  | `ExArk.Ir.Group` | IR representation of an optional field group |
  | `ExArk.Ir.Variant` | IR representation of one arm of a variant field |
  | `ExArk.Ir.SourceLocation` | Source file location metadata attached to IR nodes |
  """

  alias ExArk.Registry
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Json

  @doc """
  Load schema file(s) from disk into a new registry.

  Accepts either a single path or a list of paths. When a list is given all
  schemas and enums are merged into a single `ExArk.Registry`; duplicate
  schema or enum names across files are treated as an error.

  ## Examples

      iex> ExArk.load_schemas("#{__ENV__.file}/../test/fixtures/ir/api.ir")

  """
  @spec load_schemas([Path.t()] | Path.t()) :: {:ok, Registry.t()} | {:error, any()}
  def load_schemas(path) do
    load_schemas(%Registry{}, path)
  end

  @doc """
  Load schema file(s) from disk into a new registry, raising on error.

  Same as `load_schemas/1` but returns the `ExArk.Registry` directly and raises
  a `RuntimeError` if loading fails.

  ## Examples

      iex> ExArk.load_schemas("#{__ENV__.file}/../test/fixtures/ir/api.ir")

  """
  @spec load_schemas!([Path.t()] | Path.t()) :: Registry.t()
  def load_schemas!(path) do
    case load_schemas(%Registry{}, path) do
      {:ok, registry} ->
        registry

      error ->
        raise RuntimeError, message: "Unable to load schemas, error: #{inspect(error)}"
    end
  end

  @doc """
  Deserialize an Ark object from a file according to the given type from the
  registry.
  """
  @spec read_object_from_file(Registry.t(), String.t(), Path.t()) :: {:ok, map()} | {:error, any()}
  def read_object_from_file(%Registry{} = registry, type, path) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      with {:ok, bytes} <- File.read(path) do
        Binary.Deserialization.read_object_from_bytes(registry, schema, bytes)
      end
    end
  end

  @doc """
  Deserialize an Ark object from the given file according to the embedded type
  information. If the schema is not embedded in the serialized data, this will
  throw.
  """
  @spec read_generic_object_from_file(Path.t()) :: {:ok, any()} | {:error, any()}
  def read_generic_object_from_file(path) do
    with {:ok, bytes} <- File.read(path) do
      Binary.Deserialization.read_generic_object_from_bytes(bytes)
    end
  end

  @doc """
  Deserialize an Ark object with the given registry and type from raw bytes.
  """
  @spec read_object_from_bytes(Registry.t(), String.t(), binary()) :: {:ok, map()} | {:error, any()}
  def read_object_from_bytes(%Registry{} = registry, type, bytes) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      Binary.Deserialization.read_object_from_bytes(registry, schema, bytes)
    end
  end

  @doc """
  Deserialize an Ark object from the given bytes according to the embedded type
  information. If the schema is not embedded in the serialized data, this will
  throw.
  """
  @spec read_generic_object_from_bytes(binary()) :: {:ok, any()} | {:error, any()}
  def read_generic_object_from_bytes(bytes) do
    Binary.Deserialization.read_generic_object_from_bytes(bytes)
  end

  @doc """
  Deserialize an Ark object with the given registry and type from a JSON string.
  """
  @spec read_object_from_json(Registry.t(), String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def read_object_from_json(%Registry{} = registry, type, jsonstr) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      with sanitized <- Json.sanitize(jsonstr),
           {:ok, data} <- JSON.decode(sanitized) do
        Json.Deserialization.read_object_from_json_data(registry, schema, data)
      end
    end
  end

  @doc """
  Serialize object to an Ark object byte stream with the given registry and
  type, without embedded schema information.
  """
  @spec write_object_to_bytes(Registry.t(), String.t(), any()) :: {:ok, binary()} | {:error, any()}
  def write_object_to_bytes(%Registry{} = registry, type, data) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      Binary.Serialization.write_object_to_bytes(registry, schema, data)
    end
  end

  @doc """
  Serialize object to an Ark object byte stream with the given registry and
  type, with embedded schema information. The serialization will use the schemas
  in the provided registry, but embed a registry with only the minimal set of
  schemas needed to deserialize the object.
  """
  @spec write_generic_object_to_bytes(Registry.t(), String.t(), any()) :: {:ok, binary()} | {:error, any()}
  def write_generic_object_to_bytes(%Registry{} = registry, type, data) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      Binary.Serialization.write_generic_object_to_bytes(registry, schema, data)
    end
  end

  @doc """
  Serialize an Ark object to a JSON string with the given registry and type.
  """
  @spec write_object_to_json(Registry.t(), String.t(), any()) :: {:ok, String.t()} | {:error, any()}
  def write_object_to_json(%Registry{} = registry, type, data) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      Json.Serialization.write_object_to_json(registry, schema, data)
    end
  end

  defp load_schemas(%Registry{} = _registry, nil), do: {:error, :invalid_path}
  defp load_schemas(%Registry{} = registry, []), do: {:ok, registry}

  defp load_schemas(%Registry{} = registry, [path | rest] = _paths) do
    case load_schemas(registry, path) do
      {:ok, registry} ->
        load_schemas(registry, rest)

      error ->
        error
    end
  end

  defp load_schemas(%Registry{} = registry, path) do
    case File.read(path) do
      {:ok, data} ->
        Registry.load(registry, data)

      error ->
        error
    end
  end
end
