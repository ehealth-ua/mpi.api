defmodule MPI.Repo.Migrations.CopyDocumentsAndPhonesIntoRelatedTables do
  use Ecto.Migration
  import Ecto.Query
  @disable_ddl_transaction true
  alias MPI.{Repo, Person, PersonDocument, PersonPhone}

  def insert_fetched_attributes(persons) do
    insert_fetched_attributes(persons, [], [])
  end

  defp insert_fetched_attributes([], acc_phones, acc_documents) do
    {pn, _} = Repo.insert_all(PersonPhone, List.flatten(acc_phones))
    {dn, _} = Repo.insert_all(PersonDocument, List.flatten(acc_documents))
    {pn, dn}
  end

  defp insert_fetched_attributes([person | rest], acc_phones, acc_documents) do
    person_phone_entries = prepare_entries(person, person.phones)
    person_document_entities = prepare_entries(person, person.documents)
    insert_fetched_attributes(rest, [person_phone_entries | acc_phones], [person_document_entities | acc_documents])
  end

  defp prepare_entries(person, entries) do
    Enum.map(entries, fn entry ->
      Enum.reduce(entry, %{}, fn {k, v}, acc ->
        Map.put(acc, String.to_existing_atom(k), v)
      end)
      |> Map.put(:id, Ecto.UUID.generate())
      |> Map.put(:person_id, person.id)
      |> Map.put(:inserted_at, person.inserted_at)
      |> Map.put(:updated_at, person.updated_at)
    end)
  end

  def chunk_persons_process(limit) do
    Person
    |> select([:id, :inserted_at, :updated_at, :documents, :phones])
    |> join(:left, [p], d in PersonDocument, d.person_id == p.id)
    |> where(fragment(" p1.person_id IS NULL and p0.inserted_at >=
    COALESCE((select max(inserted_at) from person_documents), to_timestamp(0))"))
    |> order_by(:inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> case do
      [] ->
        :ok

      persons ->
        insert_fetched_attributes(persons)
        chunk_persons_process(limit)
    end
  end

  def up do
    limit = 2000
    chunk_persons_process(limit)
  end

  def down do
    # Repo.truncate(PersonPhone)
    # Repo.truncate(PersonDocument)
  end
end
