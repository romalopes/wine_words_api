class CreateBillingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_events do |t|
      t.string :provider, null: false
      t.string :provider_event_id, null: false
      t.string :event_type
      t.datetime :processed_at
      t.jsonb :payload, default: {}

      t.timestamps
    end

    add_index :billing_events, [:provider, :provider_event_id], unique: true
    add_index :billing_events, :processed_at, where: "processed_at IS NULL"
  end
end
