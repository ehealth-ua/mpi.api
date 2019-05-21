defmodule Core.Repo.Migrations.UpdatePersonDocumentsTimestamps do
  use Ecto.Migration

  import Ecto.Query

  alias Core.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.UUID

  @disable_ddl_transaction true
  @batch_size 500

  def change do
    execute("CREATE TABLE IF NOT EXISTS person_documents_update_temp AS SELECT id, inserted_at FROM persons")
    execute("CREATE INDEX IF NOT EXISTS person_documents_update_temp_index ON person_documents_update_temp(id)")

    execute("CREATE TABLE IF NOT EXISTS person_documents_update_temp2 AS SELECT id, inserted_at FROM person_documents_update_temp ORDER BY id ASC")
    flush()

    batch_update()

    execute("DROP TABLE IF EXISTS person_documents_update_temp")
    execute("DROP TABLE IF EXISTS person_documents_update_temp2")
  end

  defp batch_update do
    from(pd in "person_documents_update_temp2",
      select: {pd.id, pd.inserted_at},
      limit: @batch_size,
      order_by: :id
    )
    |> Repo.all()
    |> do_update()
  end

  defp do_update([]), do: :ok

  defp do_update(rows) do
    {last_id, _} = List.last(rows)

    update_values =
      rows
      |> Enum.map(fn {id, inserted_at} -> "('#{UUID.cast!(id)}'::uuid, '#{inserted_at}'::timestamp)" end)
      |> Enum.join(", ")

    case update_person_documents(update_values) do
      {:ok, _} ->
        drop_temp_records(last_id)
        batch_update()

      error ->
        raise "Fail to migrate person documents timestamps. Error: #{inspect(error)}"
    end
  end

  defp update_person_documents(values) do
    SQL.query(Repo, """
      UPDATE person_documents
      SET inserted_at = tmp.inserted_at
      FROM (VALUES #{values}) AS tmp (id, inserted_at)
      WHERE tmp.id = person_documents.person_id;
    """)
  end

  defp drop_temp_records(last_id) do
    SQL.query(Repo, "DELETE FROM person_documents_update_temp2 WHERE id <= '#{UUID.cast!(last_id)}'::uuid")
  end
end
