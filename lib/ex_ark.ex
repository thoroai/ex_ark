defmodule ExArk do
  @moduledoc """
  Documentation for `ExArk`.
  """

  alias ExArk.Registry
  alias ExArk.Serdes.Deserialization

  @doc """
  Load schema file(s)

  ## Examples

      iex> ExArk.load_schemas("#{__ENV__.file}/../test/fixtures/ir/api.ir")

  """
  @spec load_schemas([Path.t()] | Path.t()) :: {:ok, Registry.t()} | {:error, any()}
  def load_schemas(path) do
    load_schemas(%Registry{}, path)
  end

  @doc """
  Load schema file(s)

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
  Deserialize an Ark rbuf with the given registry and type from a file.
  """
  @spec read_object_from_file(Registry.t(), String.t(), Path.t()) :: {:ok, any()} | {:error, any()}
  def read_object_from_file(%Registry{} = registry, type, path) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      with {:ok, bytes} <- File.read(path) do
        Deserialization.read_object_from_bytes(registry, schema, bytes)
      end
    end
  end

  @doc """
  Deserialize an Ark rbuf with embedded type info from the given file.
  If the schema is not embedded in the serialized data, this will throw.
  """
  @spec read_generic_object_from_file(Path.t()) :: {:ok, any()} | {:error, any()}
  def read_generic_object_from_file(path) do
    with {:ok, bytes} <- File.read(path) do
      Deserialization.read_generic_object_from_bytes(bytes)
    end
  end

  @doc """
  Deserialize an Ark rbuf with the given registry and type from raw bytes.
  """
  @spec read_object_from_bytes(Registry.t(), String.t(), binary()) :: {:ok, any()} | {:error, any()}
  def read_object_from_bytes(%Registry{} = registry, type, bytes) do
    schema = registry.schemas[type]

    if is_nil(schema) do
      {:error, :schema_not_found}
    else
      Deserialization.read_object_from_bytes(registry, schema, bytes)
    end
  end

  @doc """
  Deserialize an Ark rbuf with embedded type info from the given raw bytes.
  If the schema is not embedded in the serialized data, this will throw.
  """
  @spec read_generic_object_from_bytes(binary()) :: {:ok, any()} | {:error, any()}
  def read_generic_object_from_bytes(bytes) do
    Deserialization.read_generic_object_from_bytes(bytes)
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
