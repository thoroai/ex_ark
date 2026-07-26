defmodule ExArk.Utilities do
  @moduledoc """
  Internal utility functions shared across ExArk modules.
  """

  @mix_env Mix.env()

  @doc """
  Convert a string to an atom, guarding against atom-table exhaustion in
  production.

  In `:test` env uses `String.to_atom/1` (allows new atoms for test fixtures).
  In all other envs uses `String.to_existing_atom/1`, which raises
  `ArgumentError` if the atom has not already been interned. When passed an atom
  it is returned unchanged.
  """
  @spec ensure_existing_atom(binary()) :: atom()
  def ensure_existing_atom(identifier) when is_binary(identifier) do
    if @mix_env == :test do
      String.to_atom(identifier)
    else
      String.to_existing_atom(identifier)
    end
  end

  @spec ensure_existing_atom(atom()) :: atom()
  def ensure_existing_atom(identifier) when is_atom(identifier), do: identifier

  @doc """
  Reverse the byte order of a binary.
  """
  @spec reverse_binary(binary()) :: binary()
  def reverse_binary(bin) when is_binary(bin) do
    reverse_binary(bin, byte_size(bin))
  end

  @doc """
  Reverse the byte order of a binary, zero-padding the result to `len` bytes.
  """
  @spec reverse_binary(binary(), non_neg_integer()) :: binary()
  def reverse_binary(bin, len) when is_binary(bin) do
    res = bin |> :binary.decode_unsigned(:little) |> :binary.encode_unsigned(:big)
    pad = len - byte_size(res)
    <<0::pad*8, res::binary>>
  end

  @doc """
  Conditionally insert a key–value pair into a map, skipping absent values.

  `value` is considered absent if it is `nil`, an empty list `[]`, or an empty
  map `%{}`. Otherwise `fun` is applied to `value` and the result is stored
  under `key`. The default `fun` is `Function.identity/1` (no transformation).
  """
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
