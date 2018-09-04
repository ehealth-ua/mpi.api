defmodule MPI.Web.MergeCandidateView do
  @moduledoc false

  use MPI.Web, :view

  def render("index.json", %{merge_candidates: merge_candidates}) do
    render_many(merge_candidates, __MODULE__, "merge_candidate.json")
  end

  def render("update.json", %{merge_candidate: merge_candidate}) do
    render_one(merge_candidate, __MODULE__, "merge_candidate.json")
  end

  def render("merge_candidate.json", %{merge_candidate: merge_candidate}) do
    %{
      id: merge_candidate.id,
      person_id: merge_candidate.person_id,
      master_person_id: merge_candidate.master_person_id,
      status: merge_candidate.status,
      inserted_at: merge_candidate.inserted_at,
      updated_at: merge_candidate.updated_at
    }
  end
end
