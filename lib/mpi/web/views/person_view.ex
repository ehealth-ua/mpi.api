defmodule MPI.Web.PersonView do
  @moduledoc false
  use MPI.Web, :view

  def render("person.json", %{person: %MPI.Person{} = person}) do
    convert_merged_ids(person)
  end

  def render("persons.json", %{persons: persons}) do
    render_many(persons, __MODULE__, "person.json", as: :person)
  end

  defp convert_merged_ids(%{merged_ids: nil} = params), do: Map.put(params, :merged_ids, [])
  defp convert_merged_ids(params), do: params
end
