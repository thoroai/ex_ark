defmodule ExArk.Ir.Group do
  @moduledoc """
  IR representation of an Ark optional field group.

  Groups provide schema versioning: fields added after the initial schema
  release are placed in a numbered group. Older serialized data that predates a
  group simply omits it; the deserializer fills in default values for the
  missing fields.

  ## Fields

    * `:identifier` — positive integer identifying the group version
    * `:fields` — list of `ExArk.Ir.Field` structs belonging to this group
  """

  use TypedStruct

  alias ExArk.Ir.Field

  typedstruct enforce: true do
    field :identifier, integer()
    field :fields, [Field.t()]
  end

  @doc """
  Parse a group from a decoded JSON term (atom-keyed map).
  """
  @spec from_json(term()) :: t()
  def from_json(json) do
    fields =
      for field_json <- json.fields do
        Field.from_json(field_json)
      end

    struct(__MODULE__, %{identifier: json.identifier, fields: fields})
  end

  @doc """
  Serialize a group struct to a plain map suitable for JSON encoding.
  """
  @spec to_map(t()) :: term()
  def to_map(%__MODULE__{} = group) do
    %{
      "identifier" => group.identifier,
      "fields" => Enum.map(group.fields, &Field.to_map/1)
    }
  end
end
