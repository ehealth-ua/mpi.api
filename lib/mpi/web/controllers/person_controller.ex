defmodule Mpi.Web.PersonController do
  @moduledoc false
  use Mpi.Web, :controller
  alias Mpi.Repo
  alias Mpi.Person
  action_fallback Mpi.Web.FallbackController

  def show(conn, %{"id" => id}) do
    with %Mpi.Person{} = person <- Repo.get(Mpi.Person, id) do
      conn
      |> put_status(:ok)
      |> render("person.json", %{person: person})
    end
  end

  def create(conn, params) do
    with %Ecto.Changeset{valid?: true} = changeset <- Person.changeset(%Person{}, params),
      {:ok, person} <- Repo.insert(changeset) do
        conn
        |> put_status(:created)
        |> render("person.json", %{person: person})
    end
  end
end
