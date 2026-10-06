# Name fields are profile data, not unique authentication identifiers.
class MoveUserNamesToAccounts < ActiveRecord::Migration[8.1]
  def up
    # SQL deliberately avoids application callbacks and model schema caches.
    execute <<~SQL
      INSERT INTO accounts (user_id, created_at, updated_at)
      SELECT users.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users
      LEFT JOIN accounts ON accounts.user_id = users.id
      WHERE accounts.id IS NULL
      ON CONFLICT (user_id) DO NOTHING
    SQL

    # Preserve names that users already entered. Only profiles with neither
    # name get a fallback from the old handle. A one-word handle has no known
    # last name; do not fabricate one or derive names from email addresses.
    execute <<~SQL
      WITH legacy_names AS (
        SELECT id, REGEXP_REPLACE(BTRIM(user_name), '\\s+', ' ', 'g') AS full_name
        FROM users
      )
      UPDATE accounts
      SET first_name = NULLIF(SPLIT_PART(legacy_names.full_name, ' ', 1), ''),
          last_name = CASE WHEN POSITION(' ' IN legacy_names.full_name) > 0
            THEN NULLIF(SUBSTRING(legacy_names.full_name FROM POSITION(' ' IN legacy_names.full_name) + 1), '')
            ELSE NULL END,
          updated_at = CURRENT_TIMESTAMP
      FROM legacy_names
      WHERE accounts.user_id = legacy_names.id
        AND COALESCE(BTRIM(accounts.first_name), '') = ''
        AND COALESCE(BTRIM(accounts.last_name), '') = ''
    SQL

    remove_column :users, :user_name, :string
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Original unique handles cannot be reconstructed from non-unique profile names. Restore a database backup to roll back."
  end
end
