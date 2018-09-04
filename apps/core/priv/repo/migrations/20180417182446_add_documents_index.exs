defmodule Core.Repo.Migrations.AddDocumentsIndex do
  @moduledoc false

  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(index(:persons, [:documents], using: "GIN", concurrently: true))
  end
end
