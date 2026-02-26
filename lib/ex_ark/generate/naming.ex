defmodule ExArk.Generate.Naming do
  @moduledoc """
  Converts Ark namespace strings to Elixir module names.

  Ark uses `::` as a namespace separator with PascalCase type names and
  lowercase namespace components (e.g. `tai::fleet::cloud::RobotStatus`).
  Each `::` segment is converted to PascalCase by uppercasing its first
  character; the remainder of each segment is left unchanged to preserve
  names like `TransformMessage2d`.
  """

  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Schema

  @doc """
  Returns the Elixir module atom for a schema, with the given namespace prefix.
  """
  @spec schema_module(Schema.t(), module()) :: module()
  def schema_module(%Schema{} = schema, namespace) do
    ark_name_to_module(Schema.object_name(schema), namespace)
  end

  @doc """
  Returns the Elixir module atom for an enum, with the given namespace prefix.
  """
  @spec enum_module(ArkEnum.t(), module()) :: module()
  def enum_module(%ArkEnum{} = enum, namespace) do
    ark_name_to_module(ArkEnum.object_name(enum), namespace)
  end

  @doc """
  Converts a fully-qualified Ark name to an Elixir module atom under the
  given namespace prefix.

  ## Examples

      iex> ExArk.Generate.Naming.ark_name_to_module("tai::fleet::cloud::RobotStatus", MyApp.Ark)
      MyApp.Ark.Tai.Fleet.Cloud.RobotStatus

      iex> ExArk.Generate.Naming.ark_name_to_module("TopLevelObject", MyApp.Ark)
      MyApp.Ark.TopLevelObject

  """
  @spec ark_name_to_module(String.t(), module()) :: module()
  def ark_name_to_module(ark_name, namespace) when is_binary(ark_name) and is_atom(namespace) do
    segments = ark_name_to_segments(ark_name)
    prefix = Module.split(namespace)
    Module.concat(prefix ++ segments)
  end

  @doc """
  Splits a fully-qualified Ark name into PascalCase string segments.

  ## Examples

      iex> ExArk.Generate.Naming.ark_name_to_segments("tai::fleet::cloud::RobotStatus")
      ["Tai", "Fleet", "Cloud", "RobotStatus"]

      iex> ExArk.Generate.Naming.ark_name_to_segments("RobotStatus")
      ["RobotStatus"]

      iex> ExArk.Generate.Naming.ark_name_to_segments("ark::TransformMessage2d")
      ["Ark", "TransformMessage2d"]

  """
  @spec ark_name_to_segments(String.t()) :: [String.t()]
  def ark_name_to_segments(ark_name) when is_binary(ark_name) do
    ark_name
    |> String.split("::")
    |> Enum.map(&upcase_first/1)
  end

  # Converts a segment to PascalCase by splitting on underscores and
  # uppercasing the first character of each part. This converts namespace
  # components like "ex_ark" -> "ExArk" and "tai" -> "Tai" while preserving
  # already-PascalCase names like "TransformMessage2d".
  defp upcase_first(segment) do
    segment
    |> String.split("_")
    |> Enum.map_join("", &upcase_first_char/1)
  end

  defp upcase_first_char(<<first::utf8, rest::binary>>) when first in ?a..?z do
    <<first - 32::utf8, rest::binary>>
  end

  defp upcase_first_char(part), do: part
end
