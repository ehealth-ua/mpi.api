defmodule PersonUpdatesProducer.Worker do
  @moduledoc """
  Runs jobs according to env
  """

  use Quantum.Scheduler, otp_app: :person_updates_producer

  alias Crontab.CronExpression.Parser
  alias PersonUpdatesProducer.Jobs.PersonUpdatesPublisher
  alias Quantum.Job
  alias Quantum.RunStrategy.Local

  def create_jobs do
    create_job(&PersonUpdatesPublisher.run/0, :person_updates_producer_schedule)
  end

  defp create_job(fun, config_name) do
    config = Confex.fetch_env!(:person_updates_producer, __MODULE__)

    __MODULE__.new_job()
    |> Job.set_overlap(false)
    |> Job.set_schedule(Parser.parse!(config[config_name]))
    |> Job.set_task(fun)
    |> Job.set_run_strategy(%Local{})
    |> __MODULE__.add_job()
  end
end
