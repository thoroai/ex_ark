defmodule ExArk.Serdes.Json do
  @moduledoc false

  alias ExArk.Serdes.Json.Fields.Primitives
  alias ExArk.Serdes.Json.Reader.Result

  @type name :: any()
  @type context :: any()
  @type serialization_failure :: {:error, name(), context()}
  @type deserialization_failure :: {:error, name(), context(), Result.t()}

  @doc """
  Sanitize the raw input JSON to mutate non-compliant fields representing
  numeric limits into natively representable values. The available JSON parsers
  for elixir do not understand the literals `Infinity`, `-Infinity` or `NaN`,
  which are not compliant with the JSON spec.
  """
  @spec sanitize(binary()) :: binary()
  def sanitize(jsonstr) do
    jsonstr
    |> String.replace(~r/\bNaN\b/, "null")
    |> String.replace(~r/\b-Infinity\b/, "-#{Primitives.inf()}")
    |> String.replace(~r/\bInfinity\b/, "#{Primitives.inf()}")
  end
end
