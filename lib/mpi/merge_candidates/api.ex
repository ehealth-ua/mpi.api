defmodule MPI.MergeCandidates.API do
  @moduledoc false

  import Ecto.Query, only: [from: 2]
  import Ecto.Changeset

  alias MPI.MergeCandidate
  alias MPI.Repo

  def get_all(attrs) do
    Repo.all(from(mc in MergeCandidate, where: ^attrs))
  end

  def get_by_id(id) do
    Repo.get(MergeCandidate, id)
  end

  def update_merge_candidate(%MergeCandidate{} = merge_candidate, params, consumer_id) do
    merge_candidate
    |> changeset(params)
    |> Repo.update_and_log(consumer_id)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:status])
  end
end
