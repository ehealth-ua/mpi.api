defmodule Deduplication.DeduplicationPool do
  @moduledoc false
  import Supervisor.Spec

  use Agent
  use Confex, otp_app: :deduplication

  alias Deduplication.Consumer
  alias Deduplication.Producer
  alias Deduplication.Worker

  def start_link(_) do
    producer_id = GenStageProducer
    parallel_consumers = config(:parallel_consumers)
    max_restarts = config(:max_restarts)

    worker_children = [
      worker(Producer, [%{id: producer_id}], id: producer_id, name: producer_id)
      | Enum.map(0..max(parallel_consumers - 1, 0), fn i ->
          consumer_id = String.to_atom("Consumer_#{i}")

          worker(Consumer, [%{producer_id: producer_id, id: consumer_id}],
            id: consumer_id,
            name: consumer_id
          )
        end)
    ]

    {:ok, _} =
      Supervisor.start_link([{Worker, []} | worker_children],
        strategy: :one_for_all,
        max_restarts: max_restarts,
        name: Deduplication.Supervisor.GenStage
      )
  end

  defp config(key) when is_atom(key), do: config()[key]
end
