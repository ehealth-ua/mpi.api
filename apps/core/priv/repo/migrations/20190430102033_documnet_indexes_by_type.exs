defmodule Core.Repo.Migrations.DocumentIndexesByType do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    execute("""
    DROP INDEX CONCURRENTLY IF EXISTS person_documents_type_lower_number_index;
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "passport_l_number_index" ON person_documents (lower(number))
    WHERE type = 'PASSPORT';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "national_id_l_number_index" ON person_documents (lower(number))
    WHERE type = 'NATIONAL_ID';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "birth_cert_l_number_index" ON person_documents (lower(number))
    WHERE type = 'BIRTH_CERTIFICATE';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "temp_passport_l_number_index" ON person_documents (lower(number))
    WHERE type = 'TEMPORARY_PASSPORT';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "protection_cert_l_number_index" ON person_documents (lower(number))
    WHERE type = 'COMPLEMENTARY_PROTECTION_CERTIFICATE';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "residence_l_number_index" ON person_documents (lower(number))
    WHERE type = 'PERMANENT_RESIDENCE_PERMIT';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "refugee_cert_l_number_index" ON person_documents (lower(number))
    WHERE type = 'REFUGEE_CERTIFICATE';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "temp_cert_l_number_index" ON person_documents (lower(number))
    WHERE type = 'TEMPORARY_CERTIFICATE';
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "rest_types_l_number_index" ON person_documents (lower(number))
    WHERE type not in ('PASSPORT', 'NATIONAL_ID', 'BIRTH_CERTIFICATE', 'TEMPORARY_PASSPORT', 'COMPLEMENTARY_PROTECTION_CERTIFICATE', 'PERMANENT_RESIDENCE_PERMIT', 'REFUGEE_CERTIFICATE', 'TEMPORARY_CERTIFICATE');
    """)
  end
end
