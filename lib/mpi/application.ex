defmodule MPI do
  @moduledoc """
  This is an entry point of mpi application.
  """
  use Application
  alias MPI.Web.Endpoint
  alias Confex.Resolver
  alias MPI.Deduplication.Scheduler
  alias MPI.Deduplication.Match

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      supervisor(MPI.Repo, []),
      # Start the endpoint when the application starts
      supervisor(MPI.Web.Endpoint, []),
      worker(MPI.Deduplication.Scheduler, [])
      # Starts a worker by calling: MPI.Worker.start_link(arg1, arg2, arg3)
      # worker(MPI.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MPI.Supervisor]
    started_app = Supervisor.start_link(children, opts)
    run_scheduler()
    started_app
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end

  # Loads configuration in `:on_init` callbacks and replaces `{:system, ..}` tuples via Confex
  @doc false
  def init(_key, config) do
    Resolver.resolve(config)
  end

  defp run_scheduler do
    import Crontab.CronExpression

    schedule = Confex.get_env(:mpi, Match)[:schedule]

    Scheduler.add_job({~e[#{schedule}], &Match.run/0})
  end
end
