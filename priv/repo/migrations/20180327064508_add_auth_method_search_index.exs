defmodule MPI.Repo.Migrations.AddAuthMethodSearchIndex do
  @moduledoc false

  use Ecto.Migration

  def change do
    execute("""
    CREATE INDEX "auth_method_search_index" ON persons (
      is_active,
      birth_date,
      status,
      lower(first_name),
      lower(last_name),
      lower(second_name)
    );
    """)
  end
end
