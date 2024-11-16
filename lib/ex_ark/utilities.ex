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

  @spec reverse_binary(binary()) :: binary()
  def reverse_binary(bin) when is_binary(bin) do
    reverse_binary(bin, byte_size(bin))
  end

  @spec reverse_binary(binary(), non_neg_integer()) :: binary()
  def reverse_binary(bin, len) when is_binary(bin) do
    res = bin |> :binary.decode_unsigned(:little) |> :binary.encode_unsigned(:big)
    pad = len - byte_size(res)
    <<res::binary, 0::pad*8>>
  end
end
