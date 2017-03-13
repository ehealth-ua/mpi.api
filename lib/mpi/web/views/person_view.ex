defmodule Mpi.Web.PersonView do
  @moduledoc false
  use Mpi.Web, :view

  def render("person.json", %{person: %Mpi.Person{} = person}) do
    person
  end
end
