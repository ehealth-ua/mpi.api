defmodule Core.MergeCandidates.API do
  @moduledoc false

  import Ecto.Query
  import Ecto.Changeset

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.Repo

  require Logger

  def get_all(attrs) do
    Repo.all(from(mc in MergeCandidate, where: ^attrs))
  end

  def get_by_id(id) do
    Repo.get(MergeCandidate, id)
  end

  def get_manual_merge_candidates(batch_size, max_candidates, score_min, score_max),
    do: do_get_manual_merge_candidates(batch_size, 0, max_candidates, score_min, score_max, [])

  defp do_get_manual_merge_candidates(limit, offset, max_candidates, _, _, acc) when offset + limit > max_candidates do
    Logger.warn("Maximum offset for MergeCandidates is reached. Is ManualMergeCandidates in processing?")
    acc
  end

  defp do_get_manual_merge_candidates(limit, offset, max_candidates, score_min, score_max, acc) do
    Logger.info(fn -> "Get candidates from MPI for Manual Merge. Limit: `#{limit}`, offset: `#{offset}`." end)

    MergeCandidate
    |> select([m], %{id: m.id, master_person_id: m.master_person_id, person_id: m.person_id})
    |> where([m], m.status == ^MergeCandidate.status(:new) and m.score >= ^score_min and m.score <= ^score_max)
    |> limit(^limit)
    |> offset(^offset)
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
    |> case do
      [] -> acc
      rows -> do_get_manual_merge_candidates(limit, limit + offset, max_candidates, score_min, score_max, acc ++ rows)
    end
  end

  def update_status_by_id(id, status, consumer_id) do
    with %MergeCandidate{} = merge_candidate <- Repo.get(MergeCandidate, id),
         {:ok, _} <- update_merge_candidate(merge_candidate, %{status: status}, consumer_id) do
      :ok
    end
  end

  def update_merge_candidate(%MergeCandidate{} = merge_candidate, params, consumer_id) do
    fields = ~w(status score)

    atom_params =
      params
      |> Map.take(fields)
      |> Enum.into(%{}, fn {k, v} -> {String.to_atom(k), v} end)

    params = if Enum.empty?(atom_params), do: Map.take(params, Enum.map(fields, &String.to_atom/1)), else: atom_params

    merge_candidate
    |> changeset(params)
    |> Repo.update_and_log(consumer_id)
  end

  def get_new_merge_candidates(score, batch_size) do
    MergeCandidate
    |> select([m], %{id: m.id, master_person_id: m.master_person_id, merge_person_id: m.person_id})
    |> where([m], m.status == ^MergeCandidate.status(:new) and m.score >= ^score)
    |> limit(^batch_size)
    |> Repo.all()
  end

  def get_status_by_master_and_merge(master_person_id, merge_person_id) do
    MergeCandidate
    |> select([m, mp, cp], %{
      id: m.id,
      master_person_id: mp.id,
      merge_person_id: cp.id,
      actual?: mp.updated_at < m.updated_at and cp.updated_at < m.updated_at
    })
    |> join(:inner, [m], mp in Person, on: m.master_person_id == mp.id)
    |> join(:inner, [m, mp], cp in Person, on: m.person_id == cp.id)
    |> where([m, mp, cp], m.master_person_id == ^master_person_id and m.person_id == ^merge_person_id)
    |> Repo.one()
  end

  def changeset(struct, params \\ %{}) do
    cast(struct, params, ~w(status score)a)
  end
end
