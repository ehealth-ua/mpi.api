defmodule MPIScheduler.Worker do
  @moduledoc false

  use Quantum.Scheduler, otp_app: :mpi_scheduler

  alias Crontab.CronExpression.Parser
  alias MPIScheduler.Jobs.AutoMergePersonsDeactivator
  alias Quantum.Job
  alias Quantum.RunStrategy.Local

  def create_jobs do
    create_job(&AutoMergePersonsDeactivator.run/0, :auto_merge_persons_deactivator_schedule)
  end

  defp create_job(fun, config_name) do
    config = Confex.fetch_env!(:mpi_scheduler, __MODULE__)

    __MODULE__.new_job()
    |> Job.set_overlap(false)
    |> Job.set_schedule(Parser.parse!(config[config_name]))
    |> Job.set_task(fun)
    |> Job.set_run_strategy(%Local{})
    |> __MODULE__.add_job()
  end
end
