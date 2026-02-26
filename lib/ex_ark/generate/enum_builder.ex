defmodule ExArk.Generate.EnumBuilder do
  @moduledoc """
  Generates `defmodule` AST for Ark enum types.

  Each generated enum module provides:

  - `@type t` — a union type of all enum value atoms
  - `values/0` — returns the full list of valid value atoms
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
    value_atoms = sorted_value_atoms(enum)
    type_ast = union_type_ast(value_atoms)
    moduledoc = DocBuilder.enum_moduledoc(enum, namespace)

    quote do
      defmodule unquote(module_name) do
        @moduledoc unquote(moduledoc)

        @typedoc "One of the valid atoms for `#{unquote(ark_name)}`."
        @type t :: unquote(type_ast)

        @doc "Returns all valid values for this enum in declaration order."
        @spec values() :: [t()]
        def values, do: unquote(value_atoms)
      end
    end
  end

  # Returns atoms sorted by their integer value, preserving declaration order.
  defp sorted_value_atoms(%ArkEnum{values: values}) do
    values
    |> Enum.sort_by(fn {_k, v} -> v end)
    |> Enum.map(fn {k, _v} -> k end)
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
