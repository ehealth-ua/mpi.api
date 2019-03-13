defmodule Core.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
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
    [
      extra_applications: [:logger],
      mod: {Core.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:confex_config_provider, "~> 0.1.0"},
      {:kube_rpc, "~> 0.1.0"},
      {:confex, "~> 3.4"},
      {:scrivener_ecto, "~> 1.2"},
      {:ecto_trail, "~> 0.3"},
      {:httpoison, "~> 1.3"},
      {:poison, "~> 3.1", override: true},
      {:postgrex, ">= 0.0.0"},
      {:timex, "~> 3.3.0"},
      {:ehealth_logger, git: "https://github.com/edenlabllc/ehealth_logger.git"},
      {:ecto_filter, git: "https://github.com/edenlabllc/ecto_filter"},
      {:mox, "~> 0.3", only: [:test]},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:ex_machina, "~> 2.0", only: [:dev, :test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create", "ecto.migrate", "test"]
    ]
  end
end
