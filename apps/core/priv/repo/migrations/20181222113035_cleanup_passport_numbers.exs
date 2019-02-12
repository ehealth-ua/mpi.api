defmodule Core.Repo.Migrations.CleanupPassportNumbers do
  use Ecto.Migration
  import Ecto.Query
  alias Core.Repo
  alias Core.PersonDocument

  @disable_ddl_transaction true

  def change do
    create_if_not_exists table(:cleanup_passport_numbers_temp) do
      add(:last_inserted_at, :naive_datetime)
    end

    flush()

    with :ok <- chunk_update(500, get_last_inserted_at()) do
      drop table(:cleanup_passport_numbers_temp)
    end
  end

  defp get_last_inserted_at do
    query = from(t in "cleanup_passport_numbers_temp", select: t.last_inserted_at)

    case Repo.all(query) do
      [last_inserted_at] ->
        last_inserted_at

      [] ->
        last_inserted_at = ~N[1970-01-01 00:00:00.000]
        Repo.insert_all("cleanup_passport_numbers_temp", [[last_inserted_at: last_inserted_at]])
        last_inserted_at
    end
  end

  defp cleanup_number(limit, last_inserted_at) do
    from(pd in PersonDocument,
      where:
        fragment(
          "id in (select id from person_documents where type = 'PASSPORT' and inserted_at >= ? order by inserted_at limit ?)",
          ^last_inserted_at,
          ^limit
        ),
      update: [
        set: [
          number:
            fragment("upper(regexp_replace(number, '\s', '', 'g'))")
        ]
      ]
    )
    |> Repo.update_all([], returning: [:inserted_at])
  end

  defp chunk_update(limit, last_inserted_at) do
    case cleanup_number(limit, last_inserted_at) do
      {0, []} ->
        :ok

      {1, _} ->
        :ok

      {_, updates} ->
        last_inserted_at =
          updates
          |> Enum.map(&Map.get(&1, :inserted_at))
          |> Enum.max_by(&DateTime.to_unix(&1, :microsecond))

        Repo.update_all("cleanup_passport_numbers_temp", set: [last_inserted_at: last_inserted_at])

        chunk_update(limit, last_inserted_at)
    end
  end
end
