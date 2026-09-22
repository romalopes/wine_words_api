class RequireWineProducer < ActiveRecord::Migration[7.1]
  # Migration-scoped models: the real Producer model declares an enum
  # (producer_type) whose column is only added by a LATER migration
  # (20260826115000_add_attributes_to_producers). Loading app models inside a
  # pending migration would raise "Undeclared attribute type for enum". Plain
  # ActiveRecord::Base subclasses bypass model validations/enums entirely.
  class MigrationProducer < ActiveRecord::Base
    self.table_name = "producers"
  end

  class MigrationWine < ActiveRecord::Base
    self.table_name = "wines"
  end

  def up
    # Backfill wines without a producer using the first producer in the DB.
    fallback = MigrationProducer.first
    fallback ||= MigrationProducer.create!(name: "Unknown Producer", email: "unknown@unknown")

    MigrationWine.where(producer_id: nil).find_each do |wine|
      wine.update_column(:producer_id, fallback.id)
    end

    change_column_null :wines, :producer_id, false
  end

  def down
    change_column_null :wines, :producer_id, true
  end
end