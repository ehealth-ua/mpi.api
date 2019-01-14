defmodule Core.Repo.Migrations.PersonAddresses do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    rename(table(:persons), :addresses, to: :person_addresses)

    create table(:person_addresses, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:person_id, :uuid, references: :persons, type: :uuid)
      add(:type, :string)
      add(:country, :string)
      add(:area, :string)
      add(:region, :string)
      add(:settlement, :string)
      add(:settlement_type, :string)
      add(:settlement_id, :string)
      add(:street_type, :string)
      add(:street, :string)
      add(:building, :string)
      add(:apartment, :string)
      add(:zip, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:person_addresses, [:person_id]))
    create(index(:person_addresses, [:settlement_id, :person_id]))
  end
end
