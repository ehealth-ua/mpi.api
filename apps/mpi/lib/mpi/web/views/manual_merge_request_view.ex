defmodule MPI.Web.ManualMergeRequestView do
  @moduledoc false

  use MPI.Web, :view

  alias MPI.Web.ManualMergeCandidateView

  def render("index.json", %{manual_merge_requests: manual_merge_requests}) do
    render_many(manual_merge_requests, __MODULE__, "show.json")
  end

  def render("show.json", %{manual_merge_request: manual_merge_request}) do
    manual_merge_request
    |> Map.take(~w(
      id
      status
      comment
      assignee_id
      inserted_at
      updated_at
    )a)
    |> Map.put(
      :manual_merge_candidate,
      ManualMergeCandidateView.render("show.json", manual_merge_request)
    )
  end
end
