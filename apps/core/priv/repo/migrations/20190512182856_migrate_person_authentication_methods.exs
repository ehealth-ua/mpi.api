defmodule Core.Repo.Migrations.MigratePersonAuthenticationMethods do
  @moduledoc """
  copy authentication methods to person_authentication_methods table
  """

  use Ecto.Migration
  import Ecto.Query
  require Logger

  alias Core.Person
  alias Core.PersonAuthenticationMethod
  alias Core.Repo
  alias Ecto.UUID

  @disable_ddl_transaction true

  def change do
    process_persons(1_000, 10_000, 0, 0)
  end

  defp process_persons(batch_size, message_batch_size, processed_count, message_processed_count) do
    case Person
         |> select([p, am], [:id, :authentication_methods, :updated_at, :inserted_at])
         |> join(:left, [p], am in PersonAuthenticationMethod, on: am.person_id == p.id)
         |> where(
           [p, am],
           fragment(
             "? IS NULL and ? <
              (select COALESCE(min(updated_at), '3000-01-01 00:00:00') from person_authentication_methods)",
             am.person_id,
             p.updated_at
           )
         )
         |> order_by([p, am], desc: p.updated_at)
         |> limit([p, am], ^batch_size)
         |> Repo.all() do
      [] ->
        if message_processed_count >= 0 do
          Logger.info("#{DateTime.utc_now()}    Processed #{processed_count} records total")
        end

        :ok

      persons ->
        persons
        |> Enum.reduce([], fn person, acc ->
          authentication_methods = process_person_authentication_methods(person)
          acc = authentication_methods ++ acc
        end)
        |> insert_authentication_methods()

        current_batch_size = Enum.count(persons)
        processed_count = processed_count + current_batch_size
        message_processed_count = message_processed_count + current_batch_size

        message_processed_count =
          if message_processed_count >= message_batch_size do
            Logger.info("#{DateTime.utc_now()}    Processed #{processed_count} records total")
            message_processed_count - message_batch_size
          else
            message_processed_count
          end

        process_persons(batch_size, message_batch_size, processed_count, message_processed_count)
    end
  end

  defp process_person_authentication_methods(%Person{
         id: id,
         authentication_methods: authentication_methods,
         updated_at: updated_at,
         inserted_at: inserted_at
       }) do
    Enum.map(authentication_methods, fn authentication_method ->
      authentication_method
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> Enum.into(%{})
      |> Map.merge(%{
        id: UUID.generate(),
        person_id: id,
        updated_at: updated_at,
        inserted_at: inserted_at
      })
    end)
  end

  defp insert_authentication_methods(changes) when is_list(changes) do
    {_, nil} = Repo.insert_all(PersonAuthenticationMethod, changes)
  end
end
