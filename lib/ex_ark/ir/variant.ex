defmodule ExArk.Ir.Variant do
  @moduledoc """
  IR representation of one arm of an Ark variant field.

  A variant field holds exactly one of several possible object types, selected
  at runtime. Each arm is identified by a zero-based index and the fully-
  qualified name of the schema it holds.

  ## Fields

    * `:index` — zero-based integer index of this arm within the variant field
    * `:object_type` — fully-qualified schema name for this arm
      (e.g. `"my::Namespace::MySchema"`)
  """

  use TypedStruct

  typedstruct enforce: true do
    field :index, integer()
    field :object_type, String.t()
  end

  @doc """
  Parse a variant arm from a decoded JSON term.

  In the Ark IR format each variant arm is encoded as a two-element list
  `[index, "fully::qualified::TypeName"]`.
  """
  @spec from_json(term()) :: t()
  def from_json(json) do
    struct(__MODULE__, %{index: hd(json), object_type: hd(tl(json))})
  end

  @doc """
  Serialize a variant arm to a two-element list `[index, object_type]`.

  This is the wire format used in Ark IR JSON and the inverse of `from_json/1`.
  """
  @spec to_list(t()) :: term()
  def to_list(%__MODULE__{} = variant) do
    [variant.index, variant.object_type]
  end
end
