defmodule MPI.Web.PersonView do
  @moduledoc false
  use MPI.Web, :view

  def render("person.json", %{person: %MPI.Person{} = person}) do
    # Temporary solution for BETA.
    Map.put(person, :confident_persons, [])
  end

  def render("persons.json", %{persons: persons}) do
    Enum.map(persons, fn(person) -> person_short(person) end)
  end

  defp person_short(person) do
    phone_number =
      person
      |> Map.fetch!(:phones)
      |> Enum.filter(fn(phone) -> phone.type == "MOBILE" end)
      |> get_phone_number()

    person
    |> Map.take([:id, :birth_place, :history, :first_name, :last_name, :second_name, :tax_id])
    |> Map.put(:phone_number, phone_number)
  end

  defp get_phone_number([]), do: nil
  defp get_phone_number([%{number: number}]), do: number

end
