defmodule MPI.Repo.Migrations.CopyDocumentsAndPhonesIntoRelatedTables do
  use Ecto.Migration
  import Ecto.Query
  require Logger
  @disable_ddl_transaction true
  alias MPI.{Repo, Person, PersonDocument, PersonPhone}

  def insert_fetched_attributes(persons) do
    insert_fetched_attributes(persons, [], [])
  end

  defp insert_fetched_attributes([], acc_phones, acc_documents) do
    Repo.transaction(fn ->
      Repo.insert_all(PersonPhone, List.flatten(acc_phones))
      Repo.insert_all(PersonDocument, List.flatten(acc_documents))
    end)
  end

  defp insert_fetched_attributes([person | rest], acc_phones, acc_documents) do
    person_phone_entries = prepare_entries(person, person.phones)
    person_document_entities = prepare_entries(person, person.documents)
    insert_fetched_attributes(rest, [person_phone_entries | acc_phones], [person_document_entities | acc_documents])
  end

  defp prepare_entries(person, entries) when is_list(entries) do
    Enum.map(entries, fn entry ->
      entry
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        Map.put(acc, String.to_atom(k), v)
      end)
      |> Map.put(:id, Ecto.UUID.generate())
      |> Map.put(:person_id, person.id)
      |> Map.put(:inserted_at, person.inserted_at)
      |> Map.put(:updated_at, person.updated_at)
    end)
  end

  defp prepare_entries(_, _) do
    []
  end

  def chunk_persons_process(limit) do
    Person
    |> select([:id, :inserted_at, :updated_at, :documents, :phones])
    |> join(:left, [p], d in PersonDocument, d.person_id == p.id)
    |> where([p, d], fragment("? IS NULL and ? <=
    (select COALESCE(min(updated_at), '01-01-3000 00:00:00') from person_documents)", d.person_id, p.updated_at))
    |> order_by(desc: :updated_at)
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
    limit = 1000
    chunk_persons_process(limit)

    create(index(:person_phones, [:type, :number], concurrently: true))
    create(index(:person_documents, [:type, :number], concurrently: true))

    drop(index(:persons, [:updated_at], concurrently: true))
    drop(index(:person_documents, [:updated_at], concurrently: true))
  end

  def down do
    create(index(:persons, [:updated_at], concurrently: true))
    create(index(:person_documents, [:updated_at], concurrently: true))

    drop(index(:person_phones, [:type, :number], concurrently: true))
    drop(index(:person_documents, [:type, :number], concurrently: true))
  end
end
