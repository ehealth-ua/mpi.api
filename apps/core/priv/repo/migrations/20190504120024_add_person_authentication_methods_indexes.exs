defmodule Core.Repo.Migrations.AddPersonAuthenticationMethodsIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    create(unique_index(:person_authentication_methods, [:person_id, :type], name: :authentication_methods_uniq_index))
    create(index(:person_authentication_methods, ["updated_at DESC"], name: :authentication_methods_updated_at_idx))
  end
end
