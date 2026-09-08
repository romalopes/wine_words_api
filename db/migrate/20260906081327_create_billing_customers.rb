class CreateBillingCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_customers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :provider_customer_id, null: false

      t.timestamps
    end

    add_index :billing_customers, [:provider, :provider_customer_id], unique: true
    add_index :billing_customers, [:user_id, :provider], unique: true
  end
end
