defmodule MPIWeb.Router do
  @moduledoc false
  use MPI.Web, :router
  use Plug.ErrorHandler

  alias Plug.LoggerJSON

  require Logger

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", MPI.Web do
    pipe_through(:api)

    get("/all-persons", PersonController, :all)
    get("/persons_internal", PersonController, :internal)
    resources("/persons/", PersonController)
    patch("/persons/:id/actions/reset_auth_method", PersonController, :reset_auth_method)
    resources("/merge_candidates", MergeCandidateController, only: [:index, :update])
  end

  defp handle_errors(%Plug.Conn{status: 500} = conn, %{kind: kind, reason: reason, stack: stacktrace}) do
    LoggerJSON.log_error(kind, reason, stacktrace)
    send_resp(conn, 500, Poison.encode!(%{errors: %{detail: "Internal server error"}}))
  end

  defp handle_errors(_, _), do: nil
end
