defmodule Core.Repo.Migrations.PersonUpdatesTriggers do
  use Ecto.Migration

  @disable_ddl_transaction true

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION insert_person_update()
    RETURNS trigger AS
    $BODY$
    BEGIN
      INSERT INTO person_updates (person_id, updated_by, updated_at, status) VALUES (NEW.id, NEW.updated_by::uuid, now(), NEW.status);
      return NEW;
    END;
    $BODY$
    LANGUAGE plpgsql;
    """)

    execute("""
    CREATE TRIGGER on_person_insert
    BEFORE INSERT
    ON persons
    FOR EACH ROW
    EXECUTE PROCEDURE insert_person_update();
    """)

    execute("""
    CREATE TRIGGER on_person_update_status
    BEFORE UPDATE
    ON persons
    FOR EACH ROW
    WHEN (NEW.status <> OLD.status)
    EXECUTE PROCEDURE insert_person_update();
    """)

    execute("ALTER table persons ENABLE TRIGGER on_person_insert;")
    execute("ALTER table persons ENABLE TRIGGER on_person_update_status;")
  end

  def down do
    execute("DROP TRIGGER IF EXISTS on_person_insert ON persons;")
    execute("DROP TRIGGER IF EXISTS on_person_update_status ON persons;")
  end
end
