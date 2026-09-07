class CreateSubscriptionBillingPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_billing_prices do |t|
      t.references :subscription, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :provider_product_id
      t.string :provider_price_id
      t.string :billing_interval, null: false, default: "year"
      t.string :currency, null: false, default: "AUD"
      t.integer :amount_cents
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :subscription_billing_prices,
              [:provider, :provider_price_id], unique: true
    add_index :subscription_billing_prices,
              [:subscription_id, :provider], unique: true
  end
end
