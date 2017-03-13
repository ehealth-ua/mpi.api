defmodule Mpi.Web.Router do
  @moduledoc false
  use Mpi.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Mpi.Web do
    pipe_through :api

    get "/persons/:id", PersonController, :get_person
    post "/persons/", PersonController, :create_person
  end
end
