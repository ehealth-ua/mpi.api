defmodule MPI.Web.PersonView do
  @moduledoc false

  use MPI.Web, :view
  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.PersonPhone

  def render("index.json", %{persons: persons}) do
    render_many(persons, __MODULE__, "show.json", as: :person)
  end

  def render("person_short.json", %{person: %{} = person, fields: fields}) do
    person
    |> Map.take(fields)
    |> Enum.reduce(%{}, fn {field, value}, person_enc -> Map.put(person_enc, to_string(field), value) end)
  end

  def render("show.json", %{person: %Person{} = person}) do
    person
    |> Map.take(extended_field(Person.fields()))
    |> Map.merge(%{
      merged_persons: render("merged_persons.json", person),
      master_persons: render("master_persons.json", person),
      documents: render("person_documents.json", person),
      phones: render("person_phones.json", person),
      addresses: render("person_address.json", person)
    })
  end

  def render("master_persons.json", %{id: person_id, master_persons: [_ | _] = master_persons}) do
    Enum.map(master_persons, fn master_person ->
      master_person
      |> Map.take(extended_field([:master_person_id]))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("master_persons.json", _), do: []

  def render("merged_persons.json", %{id: person_id, merged_persons: [_ | _] = merged_persons}) do
    Enum.map(merged_persons, fn merged_person ->
      merged_person
      |> Map.take(extended_field([:merge_person_id]))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("merged_persons.json", _), do: []

  def render("person_documents.json", %{id: person_id, documents: [_ | _] = documents}) do
    Enum.map(documents, fn document ->
      document
      |> Map.take(extended_field(PersonDocument.fields()))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_documents.json", _), do: []

  def render("person_phones.json", %{id: person_id, phones: phones}) do
    Enum.map(phones, fn phone ->
      phone
      |> Map.take(extended_field(PersonPhone.fields()))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_phones.json", _), do: []

  def render("person_address.json", %{id: person_id, addresses: addresses}) do
    Enum.map(addresses, fn address ->
      address
      |> Map.take(extended_field(PersonAddress.fields()))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_address.json", _), do: []

  defp extended_field(fields) do
    ~w(id inserted_at updated_at)a ++ fields
  end
end
