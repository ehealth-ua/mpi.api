defmodule Deduplication.Scheduler do
  @moduledoc false

  use Quantum.Scheduler, otp_app: :deduplication

  alias Crontab.CronExpression.Parser
  alias Deduplication.DeduplicationPool
  alias Quantum.Job
  alias Quantum.RunStrategy.Local

  def create_job do
    __MODULE__.new_job()
    |> Job.set_overlap(false)
    |> Job.set_schedule(Parser.parse!(get_config(:deduplication_schedule)))
    |> Job.set_task(&run/0)
    |> Job.set_run_strategy(%Local{})
    |> __MODULE__.add_job()
  end

  def run do
    # connect producer with consumer for genstage
    DeduplicationPool.subscribe()
  end

  defp get_config(key) when is_atom(key), do: Confex.fetch_env!(:deduplication, __MODULE__)[key]
end
