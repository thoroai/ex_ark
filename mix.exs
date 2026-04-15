defmodule ExArk.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_ark,
      version: version!(),
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        list_unused_filters: true,
        # Put the project-level PLT in the priv/ directory (instead of the default _build/ location)
        plt_file: {:no_warn, "priv/plts/project.plt"},
        plt_add_apps: [:mix]
      ],
      test_coverage: [
        tool: ExCoveralls
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  # Include test/support in dev so dialyzer can analyze the generated sample modules.
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:typedstruct, "~> 0.5"},
      {:ecto, "~> 3.13"},
      {:cldr_utils, "~> 2.0"},
      # Testing and Development Tools
      {:union_typespec, "~> 0.0.4", runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      check: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "credo --strict"
      ],
      check_with_dialyzer: [
        "check",
        "dialyzer"
      ]
    ]
  end

  defp version! do
    with {version, _exit_status} <- System.cmd("git", ~w[describe --tags --abbrev=0], stderr_to_stdout: true),
         {:ok, version} <- version |> String.trim_trailing("\n") |> Version.parse() do
      to_string(version)
    else
      _ ->
        raise "Could not determine version."
    end
  end
end
