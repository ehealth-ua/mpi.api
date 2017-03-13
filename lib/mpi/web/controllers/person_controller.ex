defmodule Mpi.Web.PersonController do
  @moduledoc false
  use Mpi.Web, :controller
  alias Mpi.Repo
  alias Mpi.Person
  action_fallback Mpi.Web.FallbackController

  def get_person(conn, %{"id" => id}) do
    with %Mpi.Person{} = person <- Repo.get(Mpi.Person, id) do
      conn
      |> put_status(:ok)
      |> render("person.json", %{person: person})
    end
  end

  def create_person(conn, params) do
    with {:ok, person} <- Repo.insert(Person.changeset(%Person{}, params)) do
      conn
      |> put_status(:created)
      |> render("person.json", %{person: person})
    end
  end
end
