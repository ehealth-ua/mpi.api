defmodule Deduplication.Application do
  @moduledoc false
  import Supervisor.Spec
  use Application
  use Confex, otp_app: :deduplication
  alias Deduplication.V2.PythonWorker
  alias Deduplication.Worker

  def start(_type, _args) do
    gen_consumer_impl = Deduplication.Kafka.GenConsumer
    consumer_group_name = Application.fetch_env!(:kafka_ex, :consumer_group)
    topic_names = ["deactivate_person_events"]

    consumer_group_opts = [
      heartbeat_interval: 1_000,
      commit_interval: 1_000
    ]

    children = if config(:env) == :test, do: [], else: [worker(Worker, [], restart: :transient)]

    children =
      children ++
        [
          supervisor(KafkaEx.ConsumerGroup, [
            gen_consumer_impl,
            consumer_group_name,
            topic_names,
            consumer_group_opts
          ]),
          :poolboy.child_spec(:worker, poolboy_config())
        ]

    opts = [strategy: :one_for_one, name: Deduplication.Supervisor]
    Supervisor.start_link(children, opts)
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
