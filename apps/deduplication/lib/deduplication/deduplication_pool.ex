defmodule Deduplication.DeduplicationPool do
  @moduledoc false
  import Supervisor.Spec

  use Agent
  use Confex, otp_app: :deduplication

  alias Deduplication.Consumer
  alias Deduplication.PersistentTerm
  alias Deduplication.Producer

  @producer GenStageProducer

  def consumer_ids do
    parallel_consumers = config(:parallel_consumers)
    Enum.map(0..max(parallel_consumers - 1, 0), &String.to_atom("Consumer_#{&1}"))
  end

  def children do
    [
      worker(Producer, [%{id: @producer}], id: @producer, name: @producer)
      | Enum.map(consumer_ids(), fn consumer_id ->
          worker(Consumer, [%{id: consumer_id}], id: consumer_id, name: consumer_id)
        end)
    ]
  end

  def start_link(env) do
    PersistentTerm.init_subscriptions()
    max_restarts = config(:max_restarts)
    worker_children = if env == :test, do: [], else: children()

    {:ok, _} =
      Supervisor.start_link(worker_children,
        strategy: :one_for_all,
        max_restarts: max_restarts,
        name: Deduplication.Supervisor.GenStage
      )
  end

  def subscribe do
    demand = config(:deduplication_persons_limit)

    case PersistentTerm.subscriptions() do
      nil ->
        consumer_ids()
        |> Enum.map(fn consumer ->
          with {:ok, subscription_tag} <- GenStage.sync_subscribe(consumer, to: @producer, max_demand: demand) do
            {:ok, consumer, subscription_tag}
          end
        end)
        |> PersistentTerm.store_subscriptions()

      current_subscriptions ->
        current_subscriptions
        |> Enum.map(fn {:ok, consumer, subscription_tag} ->
          with {:ok, new_subscription_tag} <-
                 GenStage.sync_resubscribe(consumer, subscription_tag, :normal, to: @producer, max_demand: demand) do
            {:ok, consumer, new_subscription_tag}
          end
        end)
        |> PersistentTerm.store_subscriptions()
    end
  end

  defp config(key) when is_atom(key), do: config()[key]
end
