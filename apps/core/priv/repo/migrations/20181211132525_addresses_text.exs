defmodule Core.Repo.Migrations.AddressesText do
  use Ecto.Migration

  def change do
    alter table(:person_addresses) do
      modify(:country, :text)
      modify(:area, :text)
      modify(:region, :text)
      modify(:settlement, :text)
      modify(:settlement_type, :text)
      modify(:street, :text)
      modify(:settlement_id, :text)
      modify(:street_type, :text)
      modify(:building, :text)
      modify(:apartment, :text)
      modify(:zip, :text)
      add(:person_first_name, :text)
      add(:person_last_name, :text)
    end

    create(index(:person_addresses, [:updated_at]))
    create(index(:person_addresses, [:settlement_id, :person_first_name, :person_id]))
    create(index(:person_addresses, [:settlement_id, :person_last_name, :person_id]))
    drop(index(:person_addresses, [:settlement_id, :person_id]))
  end
end
