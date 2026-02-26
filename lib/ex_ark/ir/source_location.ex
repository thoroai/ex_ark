defmodule ExArk.Ir.SourceLocation do
  @moduledoc """
  Source file location metadata attached to Ark IR nodes.

  When the Ark compiler emits an `.ir` file it records the `.rbuf` source file
  and line number where each schema or enum was defined. This information is
  optional and used primarily for diagnostics and tooling.

  ## Fields

    * `:filename` — path to the source `.rbuf` file
    * `:line_number` — 1-based line number within that file
  """

  use TypedStruct

  typedstruct enforce: true do
    field :filename, String.t()
    field :line_number, integer()
  end

  @doc """
  Parse a source location from a decoded JSON term (atom-keyed map).
  """
  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{filename: json.filename, line_number: json.line_number})
  end

  @doc """
  Serialize a source location struct to a plain map suitable for JSON encoding.
  """
  @spec to_map(t()) :: term()
  def to_map(%__MODULE__{} = source_location) do
    %{
      "filename" => source_location.filename,
      "line_number" => source_location.line_number
    }
  end
end
