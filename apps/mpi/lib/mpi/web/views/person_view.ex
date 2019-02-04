defmodule MPI.Web.PersonView do
  @moduledoc false

  use MPI.Web, :view
  alias Core.Person

  def render("persons.json", %{persons: persons}) do
    render_many(persons, __MODULE__, "person.json", as: :person)
  end

  def render("person.json", %{person: %Person{} = person}) do
    person
    |> Map.take(~w(
      id
      version
      first_name
      last_name
      second_name
      birth_date
      birth_country
      birth_settlement
      gender
      email
      tax_id
      unzr
      death_date
      preferred_way_communication
      invalid_tax_id
      is_active
      addresses
      secret
      emergency_contact
      confidant_person
      patient_signed
      process_disclosure_data_consent
      status
      inserted_by
      updated_by
      authentication_methods
      no_tax_id
      inserted_at
      updated_at
    )a)
    |> Map.merge(%{
      merged_ids: Map.get(person, :merged_ids, []),
      documents: render("person_documents.json", person),
      phones: render("person_phones.json", person)
    })
  end

  def render("person_documents.json", %{id: person_id, documents: [_ | _] = documents}) do
    Enum.map(documents, fn document ->
      document
      |> Map.take(~w(
        id
        type
        number
        issued_at
        expiration_date
        issued_by
        inserted_at
        updated_at
      )a)
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_documents.json", _), do: []

  def render("person_phones.json", %{id: person_id, phones: phones}) do
    Enum.map(phones, fn phone ->
      phone
      |> Map.take(~w(
        id
        type
        number
        person_id
        inserted_at
        updated_at
      )a)
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_phones.json", _), do: []
end
