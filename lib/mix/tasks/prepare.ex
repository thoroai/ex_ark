defmodule Mix.Tasks.ExArk.Prepare do
  @moduledoc """
  Alias for the project linter.
  """
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("format")
    Mix.shell().cmd("mix credo --strict")
    Mix.shell().cmd("mix test --color")

    if Enum.member?(args, "--with-dialyzer") do
      Mix.shell().cmd("mix dialyzer")
    else
      Mix.shell().info("Skipping dialyzer")
    end
  end
end
