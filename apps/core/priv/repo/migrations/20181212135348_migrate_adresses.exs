defmodule Core.Repo.Migrations.MigrateAdresses do
  @moduledoc """
  copy addresses to person_addresses table
  """
  import Ecto.Query
  use Ecto.Migration

  alias Core.Person
  alias Core.PersonAddress
  alias Core.Repo
  alias Ecto.UUID

  @disable_ddl_transaction true

  def make_person_addresses(persons) do
    persons
    |> Task.async_stream(fn
      %Person{
        addresses: addresses,
        id: id,
        last_name: last_name,
        first_name: first_name,
        updated_at: updated_at,
        inserted_at: inserted_at
      } ->
        addresses
        |> Enum.map(fn address ->
          address
          |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
          |> Enum.into(%{})
          |> Map.take(PersonAddress.fields())
          |> Map.merge(%{
            id: UUID.generate(),
            person_id: id,
            person_last_name: last_name,
            person_first_name: first_name,
            updated_at: updated_at,
            inserted_at: inserted_at
          })
        end)
    end)
    |> Enum.reduce([], fn {:ok, address}, acc -> [address | acc] end)
    |> List.flatten()
  end

  def store_addresses(addresses) do
    {_n, nil} = Repo.insert_all(PersonAddress, addresses)
  end

  def chunk_persons_process(limit) do
    Person
    |> select([p, a], %Person{
      addresses: p.addresses,
      first_name: p.first_name,
      last_name: p.last_name,
      id: p.id,
      updated_at: p.updated_at,
      inserted_at: p.inserted_at
    })
    |> join(:left, [p], a in PersonAddress, a.person_id == p.id)
    |> where(
      [p, a],
      fragment(
        "? IS NULL and ? >=
    (select COALESCE(min(updated_at), '01-01-3000 00:00:00') from person_addresses)",
        a.person_id,
        p.updated_at
      )
    )
    |> order_by([p, a], p.updated_at)
    |> limit(^limit)
    |> Repo.all()
    |> case do
      [] ->
        :ok

      persons ->
        persons
        |> make_person_addresses()
        |> store_addresses()

        chunk_persons_process(limit)
    end
  end

  def change do
    limit = 1000
    chunk_persons_process(limit)

    execute("""
    drop index if exists persons_updated_at_index;
    """)

    drop(index(:person_addresses, [:updated_at]))
  end
end
