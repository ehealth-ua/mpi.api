defmodule Core.Repo.Migrations.AddAuthenticaionMethodsIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    create(index(:persons, ["authentication_methods jsonb_path_ops"], [
      using: "GIN",
      concurrently: true
    ]))
  end
end
