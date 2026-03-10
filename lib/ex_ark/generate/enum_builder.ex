defmodule ExArk.Generate.EnumBuilder do
  @moduledoc """
  Generates `defmodule` AST for Ark enum types.

  Each generated enum module provides:

  - `@type t` — a union type of all enum value atoms
  - `names/0` — returns the full list of valid name atoms in declaration order
  - `values/0` — returns the full list of integer discriminants in declaration order
  - `value_for_name/1` — returns the integer discriminant for a name atom, or `nil`
  - `name_for_value/1` — returns the name atom for an integer discriminant, or `nil`
  """

  alias ExArk.Generate.DocBuilder
  alias ExArk.Generate.Naming
  alias ExArk.Ir.ArkEnum

  @doc """
  Builds the `defmodule` AST for the given `ArkEnum` under `namespace`.
  The returned quoted expression can be spliced into a `quote` block to
  define the module at compile time.
  """
  @spec build(ArkEnum.t(), module()) :: Macro.t()
  def build(%ArkEnum{} = enum, namespace) do
    module_name = Naming.enum_module(enum, namespace)
    ark_name = ArkEnum.object_name(enum)
    sorted_pairs = sorted_pairs(enum)
    name_atoms = Enum.map(sorted_pairs, fn {k, _v} -> k end)
    int_values = Enum.map(sorted_pairs, fn {_k, v} -> v end)
    type_ast = union_type_ast(name_atoms)
    moduledoc = DocBuilder.enum_moduledoc(enum, namespace)

    # Compile-time lookup structures.
    pairs_kw = sorted_pairs
    reverse_map = Map.new(sorted_pairs, fn {k, v} -> {v, k} end)

    quote do
      defmodule unquote(module_name) do
        @moduledoc unquote(moduledoc)

        @typedoc "One of the valid name atoms for `#{unquote(ark_name)}`."
        @type t :: unquote(type_ast)

        @doc "Returns all valid name atoms for this enum in declaration order."
        @spec names() :: [t()]
        def names, do: unquote(name_atoms)

        @doc "Returns all integer discriminants for this enum in declaration order."
        @spec values() :: [non_neg_integer()]
        def values, do: unquote(int_values)

        @doc "Returns the integer discriminant for the given name atom, or `nil` if not found."
        @spec value_for_name(t()) :: non_neg_integer() | nil
        def value_for_name(name), do: unquote(pairs_kw)[name]

        @doc "Returns the name atom for the given integer discriminant, or `nil` if not found."
        @spec name_for_value(non_neg_integer()) :: t() | nil
        def name_for_value(value), do: unquote(Macro.escape(reverse_map))[value]
      end
    end
  end

  # Returns {atom, integer} pairs sorted by integer value (declaration order).
  defp sorted_pairs(%ArkEnum{values: values}) do
    values
    |> Enum.sort_by(fn {_k, v} -> v end)
  end

  # Builds the union type AST:  :Val1 | :Val2 | :Val3
  # A single value produces just the atom.  An empty list produces none().
  defp union_type_ast([]) do
    quote do: none()
  end

  defp union_type_ast([single]) do
    single
  end

  defp union_type_ast([first | rest]) do
    Enum.reduce(rest, first, fn atom, acc ->
      {:|, [], [acc, atom]}
    end)
  end
end
