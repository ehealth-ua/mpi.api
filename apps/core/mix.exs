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
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0"},
      {:scrivener_ecto, git: "https://github.com/AlexKovalevych/scrivener_ecto.git", branch: "fix_page_number"},
      {:ecto_trail, "~> 0.4.1"},
      {:httpoison, "~> 1.4"},
      {:jason, "~> 1.1"},
      {:poison, "~> 3.0"},
      {:postgrex, "~> 0.14.1"},
      {:ehealth_logger, git: "https://github.com/edenlabllc/ehealth_logger.git"},
      {:ecto_filter, git: "https://github.com/edenlabllc/ecto_filter", branch: "ecto_3"},
      {:mox, "~> 0.4.0", only: [:test]},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:ex_machina, "~> 2.3", only: [:dev, :test]}
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
