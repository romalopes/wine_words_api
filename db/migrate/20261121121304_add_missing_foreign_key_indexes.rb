class AddMissingForeignKeyIndexes < ActiveRecord::Migration[8.1]
  def change
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_notification_events_on_actor_id ON notification_events (actor_id);
    SQL

    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_wine_packages_on_shipping_override_by_id ON wine_packages (shipping_override_by_id);
    SQL

    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_addresses_on_country_id ON addresses (country_id);
    SQL

    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_producers_on_country_id ON producers (country_id);
    SQL
  end
end
