defmodule MPI.Repo.Migrations.UpdatePerson do
  use Ecto.Migration

  def change do
    rename table(:persons), :birth_place, to: :birth_country

    alter table(:persons) do
      add :birth_settlement, :string, null: false
      modify :secret, :string, null: false
      add :patient_signed, :boolean, null: false
      add :process_disclosure_data_consent, :boolean, null: false
      add :merged_ids, :map
    end
  end
end
