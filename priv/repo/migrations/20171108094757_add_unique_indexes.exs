defmodule MPI.Repo.Migrations.AddUniqueIndexes do
  use Ecto.Migration

  def change do
    create unique_index(:persons,
      ~w(first_name last_name second_name tax_id birth_date)a,
      where: "status = 'active'"
    )
  end
end
