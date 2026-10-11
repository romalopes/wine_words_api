class UpdateIdentityFormatForErasure < ActiveRecord::Migration[8.1]
  def up
    # Update identity format check constraint to allow erased-* suffix
    execute <<-SQL
      ALTER TABLE analytics_events
      DROP CONSTRAINT IF EXISTS ck_analytics_events_identity_format;
    SQL

    execute <<-SQL
      ALTER TABLE analytics_events
      ADD CONSTRAINT ck_analytics_events_identity_format
      CHECK (identity ~ '^(account:\\d+|visitor:([0-9a-f-]{36}|erased-[0-9a-f-]+))$');
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE analytics_events
      DROP CONSTRAINT IF EXISTS ck_analytics_events_identity_format;
    SQL

    execute <<-SQL
      ALTER TABLE analytics_events
      ADD CONSTRAINT ck_analytics_events_identity_format
      CHECK (identity ~ '^(account:\\d+|visitor:[0-9a-f-]{36})$');
    SQL
  end
end