defmodule Core.Repo.Migrations.TrimSpaces do
  use Ecto.Migration
  import Ecto.Query
  alias Core.Repo
  alias Core.Person

  def change, do: chunk_update(1000)

  defp trim_name_spaces(limit, offset \\ 0) do
    from(p in Person,
      where: fragment("id in (select id from persons order by inserted_at offset ? limit ?)", ^offset, ^limit),
      update: [
        set: [
          first_name: fragment("array_to_string(regexp_split_to_array(TRIM(first_name), ' {2,}'), ' ')"),
          second_name: fragment("array_to_string(regexp_split_to_array(TRIM(second_name), ' {2,}'), ' ')"),
          last_name: fragment("array_to_string(regexp_split_to_array(TRIM(last_name), ' {2,}'), ' ')")
        ]
      ]
    )
    |> Repo.update_all([])
  end

  defp chunk_update(limit, offset \\ 0) do
    case trim_name_spaces(limit, offset) do
      {0, nil} -> :ok
      {count, nil} -> chunk_update(limit, offset + count)
    end
  end
end
