defmodule ExArk.Utilities do
  def ensure_existing_atom(identifier) when is_binary(identifier) do
    String.to_existing_atom(identifier)
  end

  def ensure_existing_atom(identifier), do: identifier
end
