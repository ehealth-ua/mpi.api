defmodule Core.Repo.Migrations.AddUnzrIndex do
  @moduledoc false

  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(index(:persons, [:unzr], concurrently: true))
  end
end
