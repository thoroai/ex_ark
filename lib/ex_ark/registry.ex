defmodule ExArk.Registry do
  @moduledoc """
  Registry for Ark schemas, loaded via Ark's IR (intermediate representation)
  format.
  """

  use TypedStruct

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Schema

  typedstruct do
    field :schemas, %{}, default: %{}
    field :enums, %{}, default: %{}
  end

  @spec load(t(), binary()) :: {:ok, any()} | {:error, any()}
  def load(%__MODULE__{} = existing_registry, data) do
    with {:ok, registry} <- build(data) do
      merge(existing_registry, registry)
    end
  end

  @spec build(binary()) :: {:ok, any()} | {:error, any()}
  def build(data) do
    with {:ok, decoded} <- JSON.decode(data) do
      decoded
      |> Cldr.Map.atomize_keys()
      |> from_json()
    end
  end

  @spec build_from(t(), Schema.t()) :: {:ok, any()} | {:error, any()}
  def build_from(%__MODULE__{} = registry, %Schema{} = _schema) do
    # TODO: re-build the registry to include _only_ the needed transitive
    # dependencies, including the top level schema itself. For now, just
    # return the whole registry (which is correct, but potentially terribly
    # inefficient if we loaded all known schemas into it).
    {:ok, registry}
  end

  @spec from_json(term()) :: {:ok, t()} | {:error, any()}
  def from_json(json) do
    schemas =
      for schema_json <- json.schemas do
        Schema.from_json(schema_json)
      end

    schemas =
      Enum.into(schemas, %{}, fn schema ->
        {schema.object_namespace <> "::" <> schema.name, schema}
      end)

    enums =
      for enum_json <- json.enums do
        ArkEnum.from_json(enum_json)
      end

    enums =
      Enum.into(enums, %{}, fn enum -> {enum.object_namespace <> "::" <> enum.name, enum} end)

    try do
      {:ok, struct(__MODULE__, %{schemas: schemas, enums: enums})}
    rescue
      _error ->
        {:error, :bad_registry}
    end
  end

  @spec to_json(t()) :: {:ok, binary()} | {:error, any()}
  def to_json(%__MODULE__{} = _registry) do
    # TODO
    {:ok, ""}
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
