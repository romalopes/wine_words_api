class RequireWineProducer < ActiveRecord::Migration[7.1]
  def up
    # Backfill wines without a producer using the first producer in the DB.
    if Producer.none?
      raise ActiveRecord::IrreversibleMigration,
            "Cannot make wines.producer_id NOT NULL: there are no producers to assign."
    end
    Producer.first || Producer.create!(name: "Unknown Producer", email: "unknown@unknown")
    fallback_producer_id = Producer.first.id
    Wine.where(producer_id: nil).find_each do |wine|
      wine.update_column(:producer_id, fallback_producer_id)
    end

    change_column_null :wines, :producer_id, false
  end

  def down
    change_column_null :wines, :producer_id, true
  end
end