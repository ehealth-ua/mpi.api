defmodule MPI.Web.MergeCandidateView do
  @moduledoc false

  use MPI.Web, :view

  alias MPI.Web.PersonView

  @fields ~w(
    id
    person_id
    master_person_id
    status
    inserted_at
    updated_at
  )a

  def render("index.json", %{merge_candidates: merge_candidates}) do
    render_many(merge_candidates, __MODULE__, "show.json")
  end

  def render("update.json", %{merge_candidate: merge_candidate}) do
    render_one(merge_candidate, __MODULE__, "show.json")
  end

  def render("show.json", %{merge_candidate: merge_candidate}) do
    Map.take(merge_candidate, @fields)
  end

  def render("show_with_references.json", %{merge_candidate: merge_candidate}) do
    merge_candidate
    |> Map.take(@fields)
    |> Map.merge(%{
      person: PersonView.render("show.json", %{person: merge_candidate.person}),
      master_person: PersonView.render("show.json", %{person: merge_candidate.master_person})
    })
  end
end
