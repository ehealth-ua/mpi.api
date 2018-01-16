defmodule MPI.Mixfile do
  use Mix.Project

  @version "1.58.3"

  def project do
    [app: :mpi,
     version: @version,
     elixir: "~> 1.5",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test]]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {MPI, []},
     extra_applications: [:logger, :runtime_tools]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:distillery, "~> 1.4.1"},
     {:cowboy, "~> 1.0"},
     {:phoenix, "~> 1.3.0-rc"},
     {:phoenix_ecto, "~> 3.2"},
     {:confex, ">= 0.0.0"},
     {:httpoison, ">= 0.0.0"},
     {:scrivener_ecto, "~> 1.2"},
     {:ecto_trail, "~> 0.2.4"},
     {:poison, "~> 3.1", override: true},
     {:eview, ">= 0.0.0"},
     {:postgrex, ">= 0.0.0"},
     {:timex, "~> 3.1.0"},
     {:quantum, "~> 2.0.0"},
     {:plug_logger_json, "~> 0.5"},
     {:ecto_logger_json, "~> 0.1"},
     {:excoveralls, ">= 0.0.0", only: [:dev, :test]},
     {:dogma, ">= 0.0.0", only: [:dev, :test]},
     {:credo, ">= 0.0.0", only: [:dev, :test]},
     {:ex_machina, ">= 1.0.0", only: [:test]}]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "test": ["ecto.reset --quiet", "test"]]
  end
end
