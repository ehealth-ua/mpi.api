defmodule Core.Repo.Migrations.AddPersonIndex do
  @moduledoc false

  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(index(:persons, [:is_active, :status, :birth_date, :tax_id], concurrently: true))
  end
end
