defmodule Mpi.Web.PersonController do
  @moduledoc false
  use Mpi.Web, :controller
  alias Mpi.Repo
  action_fallback Mpi.Web.FallbackController

  def get_person(conn, %{"id" => id}) do
    with %Mpi.Person{} = person <- Repo.get(Mpi.Person, id) do
      conn
      |> put_status(:ok)
      |> render("person.json", %{person: person})
    end
  end
end
