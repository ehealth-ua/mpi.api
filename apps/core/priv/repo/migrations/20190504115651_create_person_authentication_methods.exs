defmodule Core.Repo.Migrations.CreatePersonAuthenticationMethods do
  use Ecto.Migration

  def change do
    create table(:person_authentication_methods, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:person_id, :uuid, references: :persons, type: :uuid)
      add(:type, :string)
      add(:phone_number, :string)
      timestamps(type: :utc_datetime_usec)
    end

    create(index(:person_authentication_methods, [:person_id]))
  end
end
