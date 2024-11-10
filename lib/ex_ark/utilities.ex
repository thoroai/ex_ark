defmodule ExArk.Utilities do
  def ensure_existing_atom(identifier) when is_binary(identifier) do
    # TODO: remove once we know we are enumerating these somewhere that they will
    # exist, such that the `String.to_existing_atom()` call will always succeed.
    _atoms = [:uint8, :uint16, :uint32, :uint64, :int8, :int16, :int32, :uint64, :float, :double, :bool]

    String.to_existing_atom(identifier)
  end

  def ensure_existing_atom(identifier), do: identifier
end
