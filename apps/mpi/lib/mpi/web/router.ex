defmodule MPIWeb.Router do
  @moduledoc false

  use MPI.Web, :router
  require Logger

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", MPI.Web do
    pipe_through(:api)

    resources("/persons/", PersonController)
    patch("/persons/:id/actions/reset_auth_method", PersonController, :reset_auth_method)
    resources("/merge_candidates", MergeCandidateController, only: [:index, :update])
  end
end
