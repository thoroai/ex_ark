defmodule ExArk.Constants do
  @moduledoc """
  Provides macros for defining reusable constants within your modules.

  ## Usage

  To use `ExArk.Constants` in a module, you can simply call `use ExArk.Constants`, which imports the required macros.

  ### Defining a Constant

  You can define constants using the `constant/2` macro. The constants are accessible as functions that return the defined value.

  Example:
  ```elixir
  defmodule MyModule do
    use ExArk.Constants

    constant(:pi, 3.14)
    constant(:app_name, "MyApp")
  end

  IO.puts MyModule.pi()        # Outputs: 3.14
  IO.puts MyModule.app_name()  # Outputs: MyApp
  """

  defmacro __using__(_opts) do
    quote do
      import ExArk.Constants

      Module.register_attribute(__MODULE__, :constants, accumulate: true, persist: false)
    end
  end

  @doc """
  Creates a constant with a name and a value.
  """
  defmacro constant(name, value, opts \\ []) when is_atom(name) do
    defconst(name, value, opts)
  end

  defp defconst(name, value, opts) do
    const = make_const_def(name, value, opts[:macro])

    quote do
      Module.put_attribute(__MODULE__, :constants, %{name: unquote(name), value: unquote(value), opts: unquote(opts)})
      unquote(const)
    end
  end

  defp make_const_def(name, value, macro) when is_nil(macro) or not macro do
    quote do
      def unquote(name)(), do: unquote(value)
    end
  end

  defp make_const_def(name, value, true) do
    quote do
      defmacro unquote(name)() do
        const_val = unquote(value)
        quote do: unquote(const_val)
      end
    end
  end
end
