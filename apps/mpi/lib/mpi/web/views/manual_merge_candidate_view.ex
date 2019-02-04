defmodule MPI.Web.ManualMergeCandidateView do
  @moduledoc false

  use MPI.Web, :view

  alias MPI.Web.MergeCandidateView

  def render("show.json", %{manual_merge_candidate: manual_merge_candidate}) do
    manual_merge_candidate
    |> Map.take(~w(
      id
      status
      decision
      assignee_id
      person_id
      master_person_id
      inserted_at
      updated_at
    )a)
    |> Map.put(
      :merge_candidate,
      MergeCandidateView.render("show_with_references.json", manual_merge_candidate)
    )
  end
end
