defmodule Core.Repo.Migrations.PersonAddresses do
  use Ecto.Migration

  alias Core.VerifiedTs
  alias Core.Repo

  @disable_ddl_transaction true

  def change do
    create table(:person_addresses, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:person_id, :uuid, references: :persons, type: :uuid)
      add(:type, :string)
      add(:country, :text)
      add(:area, :text)
      add(:region, :text)
      add(:settlement, :text)
      add(:settlement_type, :text)
      add(:settlement_id, :uuid)
      add(:street_type, :text)
      add(:street, :text)
      add(:building, :text)
      add(:apartment, :text)
      add(:zip, :text)
      add(:person_first_name, :text)
      add(:person_last_name, :text)
      timestamps(type: :utc_datetime)
    end

    create(index(:person_addresses, [:person_id]))
    create(index(:person_addresses, [:updated_at]))
    create(index(:person_addresses, [:settlement_id, :person_first_name, :person_id]))
    create(index(:person_addresses, [:settlement_id, :person_last_name, :person_id]))

    {:ok, min_updated_at, 0} = DateTime.from_iso8601("1970-01-01T00:00:00+00")
    Repo.insert!(%VerifiedTs{id: 0, updated_at: min_updated_at})
  end
end
