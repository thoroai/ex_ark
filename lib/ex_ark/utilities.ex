defmodule ExArk.Utilities do
  @moduledoc """
  Common utilities
  """

  @spec ensure_existing_atom(binary()) :: atom()
  def ensure_existing_atom(identifier) when is_binary(identifier) do
    if Mix.env() == :test do
      String.to_atom(identifier)
    else
      String.to_existing_atom(identifier)
    end
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
    <<0::pad*8, res::binary>>
  end

  @spec maybe_add_map_value(map(), any(), any(), fun()) :: map()
  def maybe_add_map_value(map, key, value, fun \\ &Function.identity/1)
  def maybe_add_map_value(map, _key, nil, _fun), do: map
  def maybe_add_map_value(map, _key, [], _fun), do: map

  def maybe_add_map_value(map, key, [_first | _rest] = list, fun) do
    Map.merge(map, %{key => Enum.map(list, fun)})
  end

  def maybe_add_map_value(map, _key, %{} = value, _fun) when is_map(value) and map_size(value) == 0, do: map

  def maybe_add_map_value(map, key, value, fun) do
    Map.merge(map, %{key => fun.(value)})
  end
end
