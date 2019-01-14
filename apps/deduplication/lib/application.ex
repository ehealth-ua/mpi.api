defmodule Deduplication.Application do
  @moduledoc false
  import Supervisor.Spec

  use Application
  use Confex, otp_app: :deduplication
  alias Deduplication.Consumer
  alias Deduplication.Producer
  alias Deduplication.V2.PythonWorker

  def start(_type, _args) do
    poolboy_supervisor =
      Supervisor.start_link([:poolboy.child_spec(:worker, poolboy_config())],
        strategy: :one_for_one,
        name: Deduplication.Supervisor
      )

    producer_id = String.to_atom("Producer#{0}")
    parallel_consumers = config()[:parallel_consumers]

    worker_children =
      if config(:env) == :test,
        do: [],
        else: [
          worker(
            Producer,
            [%{id: producer_id}],
            id: producer_id,
            name: producer_id
          )
          | Enum.map(0..max(parallel_consumers - 1, 0), fn i ->
              consumer_id = String.to_atom("Consumer#{0}_#{i}")

              worker(Consumer, [%{producer_id: producer_id, id: consumer_id}],
                id: consumer_id,
                name: consumer_id
              )
            end)
        ]

    {:ok, _} =
      Supervisor.start_link(worker_children,
        strategy: :one_for_one,
        name: String.to_atom("Deduplication.Consumers#{0}Supervisor")
      )

    poolboy_supervisor
  end

  defp poolboy_config do
    [
      {:name, {:local, :python_workers}},
      {:worker_module, PythonWorker},
      {:size, System.schedulers_online()},
      {:max_overflow, 0}
    ]
  end

  defp config(key) when is_atom(key), do: config()[key]
end
