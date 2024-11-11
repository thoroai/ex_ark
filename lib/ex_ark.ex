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
      {:ok, registry}

  """
  @spec load_schemas([Path.t()] | Path.t()) :: {:ok, Registry.t()} | {:error, any()}
  def load_schemas(path) do
    load_schemas(%Registry{}, path)
  end

  @doc """
  Load schema file(s)

  ## Examples

      iex> ExArk.load_schemas("#{__ENV__.file}/../test/fixtures/ir/api.ir")
      registry

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
  Deserialize an Ark rbuf.
  """
  @spec read(Registry.t(), String.t(), Path.t()) :: {:ok, any()} | {:error, any()}
  def read(%Registry{} = registry, type, path) do
    schema = registry.schemas[type]
    Deserialization.read(registry, schema, path)
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
    Registry.load_schemas(registry, path)
  end
end
