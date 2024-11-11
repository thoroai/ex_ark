defmodule ExArk.Utilities do
  @moduledoc """
  Common utilities
  """

  @spec ensure_existing_atom(binary()) :: atom()
  def ensure_existing_atom(identifier) when is_binary(identifier) do
    String.to_existing_atom(identifier)
  end

  @spec ensure_existing_atom(atom()) :: atom()
  def ensure_existing_atom(identifier) when is_atom(identifier), do: identifier
end
