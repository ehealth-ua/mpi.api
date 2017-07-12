defmodule MPI.Web.PersonView do
  @moduledoc false
  use MPI.Web, :view

  def render("person.json", %{person: %MPI.Person{} = person}) do
    person
  end

  def render("persons.json", %{persons: persons, search_params: search}) do
    Enum.map(persons, fn(person) -> person_short(person, search) end)
  end

  defp person_short(person, search) do
    phone_number =
      person
      |> Map.fetch!(:phones)
      |> Enum.filter(fn(phone) -> phone["type"] == "MOBILE" end)
      |> get_phone_number()

    take_fields =
      search.changes
      |> Map.keys()

    person
    |> Map.take(take_fields ++ [:id, :history])
    |> add_phone_number_to_map(phone_number, take_fields)
  end

  defp get_phone_number([]), do: nil
  defp get_phone_number([%{"number" => number}]), do: number

  defp add_phone_number_to_map(map, phone_number, take_fields) do
    case Enum.member?(take_fields, :phone_number) do
      false -> map
      true -> Map.put(map, :phone_number, phone_number)
    end
  end
end
