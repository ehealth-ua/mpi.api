defmodule CandidatesMerger do
  @moduledoc false

  use Confex, otp_app: :candidates_merger

  import Core.ManualMerge,
    only: [
      update_and_log: 3,
      fetch_merge_request_by_id: 1,
      preload_merge_request_associations: 1
    ]

  import Ecto.Query

  alias Core.DeduplicationRepo
  alias Core.{ManualMergeCandidate, ManualMergeRequest}

  @status_new ManualMergeRequest.status(:new)
  @status_split ManualMergeRequest.status(:split)
  @status_merge ManualMergeRequest.status(:merge)
  @status_trash ManualMergeRequest.status(:trash)
  @status_postpone ManualMergeRequest.status(:postpone)
  @status_processed ManualMergeCandidate.status(:processed)
  @status_reason_auto_merge ManualMergeCandidate.status_reason(:auto_merge)

  @reason "MANUAL_MERGE"

  @kafka_producer Application.get_env(:candidates_merger, :producer)

  def process_merge_request(id, status, actor_id, comment \\ nil) when is_binary(actor_id) do
    with {:ok, merge_request} <- fetch_merge_request_by_id(id),
         :ok <- validate_assignee(merge_request, actor_id),
         :ok <- validate_status_transition(merge_request, status) do
      DeduplicationRepo.transaction(fn ->
        with {:ok, merge_request} <- update_and_log(merge_request, %{status: status, comment: comment}, actor_id),
             merge_request <- DeduplicationRepo.preload(merge_request, [:manual_merge_candidate]),
             {:ok, manual_merge_candidate} <- process_merge_candidates(merge_request, actor_id),
             :ok <- deactivate_person(manual_merge_candidate, actor_id) do
          merge_request
          |> Map.put(:manual_merge_candidate, manual_merge_candidate)
          |> preload_merge_request_associations()
        else
          {:error, reason} -> DeduplicationRepo.rollback(reason)
        end
      end)
    end
  end

  defp validate_assignee(%ManualMergeRequest{assignee_id: assignee_id}, assignee_id), do: :ok
  defp validate_assignee(_, _), do: {:error, {:forbidden, "Current client is not allowed to access this resource"}}

  defp validate_status_transition(%ManualMergeRequest{status: @status_new}, update_status)
       when update_status in [@status_split, @status_merge, @status_trash, @status_postpone],
       do: :ok

  defp validate_status_transition(%ManualMergeRequest{status: @status_postpone}, update_status)
       when update_status in [@status_split, @status_merge, @status_trash],
       do: :ok

  defp validate_status_transition(_, _), do: {:error, {:conflict, "Incorrect transition status"}}

  defp process_merge_candidates(%ManualMergeRequest{status: @status_postpone} = request, actor_id) do
    with {:ok, candidate} <- update_and_log(request.manual_merge_candidate, %{assignee_id: nil}, actor_id) do
      {:ok, candidate}
    end
  end

  defp process_merge_candidates(%ManualMergeRequest{} = request, actor_id) do
    if quorum_obtained?(request) do
      with update_data <- %{status: @status_processed, decision: request.status, assignee_id: nil},
           {:ok, candidate} <- update_and_log(request.manual_merge_candidate, update_data, actor_id),
           :ok <- process_related_merge_candidates(request, actor_id) do
        {:ok, candidate}
      end
    else
      with {:ok, candidate} <- update_and_log(request.manual_merge_candidate, %{assignee_id: nil}, actor_id) do
        {:ok, candidate}
      end
    end
  end

  defp process_related_merge_candidates(%ManualMergeRequest{status: @status_merge} = request, actor_id) do
    person_id = request.manual_merge_candidate.person_id
    candidate_id = request.manual_merge_candidate.id

    update_data = [
      decision: @status_merge,
      status: @status_processed,
      status_reason: @status_reason_auto_merge,
      assignee_id: nil,
      updated_at: DateTime.utc_now()
    ]

    ManualMergeCandidate
    |> where([c], c.id != ^candidate_id)
    |> where([c], c.person_id == ^person_id or c.master_person_id == ^person_id)
    |> DeduplicationRepo.update_all_and_log([set: update_data], actor_id)

    :ok
  end

  defp process_related_merge_candidates(_, _), do: :ok

  defp deactivate_person(%ManualMergeCandidate{decision: @status_merge} = candidate, actor_id) do
    event = %{
      id: candidate.merge_candidate_id,
      master_person_id: candidate.master_person_id,
      merge_person_id: candidate.person_id
    }

    case @kafka_producer.publish_person_deactivation_event(event, actor_id, @reason) do
      :ok -> :ok
      err -> {:error, "Cannot publish message for person deactivation in Kafka with #{inspect(err)}}"}
    end
  end

  defp deactivate_person(_, _), do: :ok

  defp quorum_obtained?(%ManualMergeRequest{manual_merge_candidate_id: candidate_id, status: status}) do
    requests =
      ManualMergeRequest
      |> select([m], count(m.id))
      |> where([m], m.manual_merge_candidate_id == ^candidate_id)
      |> where([m], m.status == ^status)
      |> DeduplicationRepo.one()

    config()[:quorum] <= requests
  end
end
