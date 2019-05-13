defmodule Core.Repo.Migrations.UpdatePersonDocumentsTimestamps do
  use Ecto.Migration

  alias Core.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.UUID

  import Ecto.Query

  @disable_ddl_transaction true
  @batch_size 100

  def change do
    execute("CREATE TABLE IF NOT EXISTS person_documents_update_temp AS SELECT id, inserted_at FROM persons")
    flush()

    chunk_update()

    execute("DROP TABLE person_documents_update_temp")
  end

  defp chunk_update do
    from(pd in "person_documents_update_temp",
      select: {pd.id, pd.inserted_at},
      limit: @batch_size
    )
    |> Repo.all()
    |> do_update()
  end

  defp do_update([]), do: :ok

  defp do_update(rows) do
    {ids, update_values} =
      Enum.reduce(rows, {[], []}, fn {id, inserted_at}, {ids, patch} ->
        {
          [id | ids],
          [
            "('#{UUID.cast!(id)}'::uuid, '#{inserted_at}'::timestamp)"
            | patch
          ]
        }
      end)

    case update_person_documents(Enum.join(update_values, ", ")) do
      {:ok, _} ->
        delete_temp_records(ids)
        chunk_update()

      err ->
        raise "Fail to migrate person documents timestamps. Error: #{inspect(err)}"
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

  defp delete_temp_records(ids) do
    from(pd in "person_documents_update_temp", where: pd.id in ^ids) |> Repo.delete_all()
  end
end
