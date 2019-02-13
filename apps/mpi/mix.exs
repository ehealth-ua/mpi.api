defmodule MPI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :mpi,
      version: "0.1.0",
      elixir: "~> 1.8.1",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {MPI, []}, extra_applications: [:logger]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.4"},
      {:phoenix_ecto, "~> 3.2"},
      {:confex, "~> 3.4"},
      {:httpoison, ">= 0.0.0"},
      {:poison, "~> 3.1", override: true},
      {:eview, ">= 0.0.0"},
      {:postgrex, ">= 0.0.0"},
      {:timex, "~> 3.3.0"},
      {:plug_logger_json, "~> 0.5"},
      {:core, in_umbrella: true},
      {:person_deactivator, in_umbrella: true}
    ]
  end

  defp aliases do
    [
      "ecto.setup": fn _ -> Mix.shell().cmd("cd ../core && mix ecto.setup") end
    ]
  end
end
