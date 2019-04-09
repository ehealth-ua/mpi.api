defmodule Deduplication.Sheduler do
  @moduledoc false

  use Quantum.Scheduler, otp_app: :deduplication

  alias Crontab.CronExpression.Parser
  alias Quantum.Job
  alias Quantum.RunStrategy.Local

  def create_job(fun) do
    config = Confex.fetch_env!(:deduplication, __MODULE__)

    __MODULE__.new_job()
    |> Job.set_overlap(false)
    |> Job.set_schedule(Parser.parse!(config[:deduplication_schedule]))
    |> Job.set_task(fun)
    |> Job.set_run_strategy(%Local{})
    |> __MODULE__.add_job()
  end
end
