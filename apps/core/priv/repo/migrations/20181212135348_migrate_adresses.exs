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
      %{
        id: id,
        addresses: addresses,
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

  def chunk_persons_process(:done, _), do: :ok

  def chunk_persons_process(:cont, limit) do
    persons =
      Person
      |> select([p, a], [:id, :addresses, :updated_at, :inserted_at])
      |> join(:left, [p], a in PersonAddress, a.person_id == p.id)
      |> where(
        [p, a],
        fragment(
          "? IS NULL and ? <
    (select COALESCE(min(updated_at), '3000-01-01 00:00:00') from person_addresses)",
          a.person_id,
          p.updated_at
        )
      )
      |> order_by([p, a], desc: p.updated_at)
      |> limit(^limit)
      |> Repo.all()

    status =
      if [] == persons do
        :done
      else
        persons
        |> make_person_addresses()
        |> store_addresses()

        :cont
      end

    chunk_persons_process(status, limit)
  end

  def change do
    limit = 1000
    chunk_persons_process(:cont, limit)

    drop(index(:person_addresses, [:updated_at]))
  end
end
