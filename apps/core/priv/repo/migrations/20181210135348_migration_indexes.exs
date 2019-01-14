defmodule Core.Repo.Migrations.UpdtadetAtIndx do
  @moduledoc """
  move addresses to person_addresses table
  """

  use Ecto.Migration

  def change do
    execute("""
    create index if not exists persons_updated_at_index on persons(updated_at desc);
    """)
  end
end
