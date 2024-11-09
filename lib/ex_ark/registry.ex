defmodule ExArk.Registry do
  @moduledoc """
  Registry for Ark schemas, loaded via Ark's IR (intermediate representation)
  format.
  """

  use TypedStruct

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Schema

  @jason_load_options [keys: :atoms]

  typedstruct do
    field :schemas, %{}, default: %{}
    field :enums, %{}, default: %{}
  end

  @spec load_schemas(t(), Path.t()) :: {:ok, any()} | {:error, any()}
  def load_schemas(%__MODULE__{} = registry, path) do
    with {:ok, file} <- File.read(path),
         {:ok, decoded} <- Jason.decode(file, @jason_load_options) do
      merge(registry, from_json(decoded))
    end
  end

  @spec from_json(term()) :: t()
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

    struct(__MODULE__, %{schemas: schemas, enums: enums})
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
