defmodule MPI.MixProject do
  @moduledoc false

  use Mix.Project

  @version "2.4.2"
  def project do
    [
      version: @version,
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      docs: [
        filter_prefix: "MPI.Rpc"
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      {:distillery, "~> 2.0", runtime: false},
      {:excoveralls, "~> 0.10.0", only: [:dev, :test]},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:git_ops, "~> 0.6.0", only: [:dev]}
    ]
  end
end
