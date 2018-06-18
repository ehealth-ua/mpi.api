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

  def chunk_persons_process(limit, offset) do
    Person
    |> select([:id, :inserted_at, :updated_at, :documents, :phones])
    |> order_by(:inserted_at)
    |> offset(^offset)
    |> limit(^limit)
    |> Repo.all()
    |> case do
      [] ->
        :ok

      persons ->
        Logger.info(fn -> "Run migration with offset: #{inspect(offset)}, limit #{inspect(limit)}" end)
        insert_fetched_attributes(persons)
        chunk_persons_process(limit, limit + offset)
    end
  end

  defp get_current_offset() do
    System.get_env("PERSON_MIGRATION_OFFSET")
    |> case do
      nil -> 0
      offset -> offset
    end
  end

  def up do
    limit = 2000
    offset = chunk_persons_process(limit, get_current_offset())
  end

  def down do
    Repo.truncate(PersonPhone)
    Repo.truncate(PersonDocument)
  end
end
