defmodule MPI.Web.MergeCandidateController do
  @moduledoc false

  use MPI.Web, :controller

  alias MPI.MergeCandidate
  alias MPI.MergeCandidates.API
  alias MPI.ConnUtils

  action_fallback(MPI.Web.FallbackController)

  def index(conn, params) do
    merge_candidates = API.get_all(prepare_params(params))
    render(conn, %{merge_candidates: merge_candidates})
  end

  def update(conn, %{"id" => id, "merge_candidate" => attrs}) do
    consumer_id = ConnUtils.get_consumer_id(conn)

    with %MergeCandidate{} = merge_candidate <- API.get_by_id(id),
         {:ok, updated_merge_candidate} <- API.update_merge_candidate(merge_candidate, attrs, consumer_id) do
      render(conn, %{merge_candidate: updated_merge_candidate})
    end
  end

  defp prepare_params(params) do
    for {key, value} <- params, into: [], do: {String.to_atom(key), value}
  end
end
