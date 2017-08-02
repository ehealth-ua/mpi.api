defmodule MPI.Web.MergeCandidateControllerTest do
  @moduledoc false

  use MPI.Web.ConnCase

  alias MPI.Factory

  test "GET /merge_candidates", %{conn: conn} do
    merge_candidate_1 = Factory.insert(:merge_candidate, status: "NEW")
    merge_candidate_2 = Factory.insert(:merge_candidate, status: "MERGED")

    response =
      conn
      |> get("/merge_candidates?status=NEW")
      |> json_response(200)

    returned_merged_candidates = Enum.map(response["data"], &(&1["id"]))

    assert merge_candidate_1.id in returned_merged_candidates
    refute merge_candidate_2.id in returned_merged_candidates
  end

  test "update /merge_candidates/:id", %{conn: conn} do
    merge_candidate = Factory.insert(:merge_candidate, status: "NEW")
    id = merge_candidate.id

    response =
      conn
      |> patch("/merge_candidates/#{id}", %{merge_candidate: %{status: "MERGED"}})
      |> json_response(200)

    assert id = response["data"]["id"]
    assert "MERGED" = response["data"]["status"]

    assert "MERGED" = MPI.Repo.get(MPI.MergeCandidate, id).status
  end
end
