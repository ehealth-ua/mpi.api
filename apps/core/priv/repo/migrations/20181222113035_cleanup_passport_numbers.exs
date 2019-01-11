defmodule Core.Repo.Migrations.CleanupPassportNumbers do
  use Ecto.Migration
  import Ecto.Query
  alias Core.Repo
  alias Core.PersonDocument

  def change, do: chunk_update(10000)

  defp cleanup_number(limit, offset) do
    from(pd in PersonDocument,
      where:
        fragment(
          "id in (select id from person_documents where type = 'PASSPORT' order by inserted_at offset ? limit ?)",
          ^offset,
          ^limit
        ),
      update: [
        set: [
          number:
            fragment("upper(array_to_string(regexp_split_to_array(TRIM(number), ' {2,}'), ' '))")
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp chunk_update(limit, offset \\ 0) do
    case cleanup_number(limit, offset) do
      {0, nil} -> :ok
      {count, nil} -> chunk_update(limit, offset + count)
    end
  end
end
