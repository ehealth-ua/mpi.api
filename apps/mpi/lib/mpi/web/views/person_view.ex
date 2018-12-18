defmodule MPI.Web.PersonView do
  @moduledoc false

  use MPI.Web, :view
  alias Core.Person

  def render("person.json", %{person: %Person{} = person}) do
    convert_merged_ids(person)
  end

  def render("persons.json", %{persons: persons}) do
    render_many(persons, __MODULE__, "person.json", as: :person)
  end

  defp convert_merged_ids(
         %Person{person_addresses: person_addresses, addresses: addresses, merged_ids: merged_ids} =
           person
       ),
       do:
         Map.merge(person, %{
           merged_ids: merged_ids || [],
           addresses: addresses ++ person_addresses
         })
end
