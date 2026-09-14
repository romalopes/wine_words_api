class CreateSubscriptionChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_changes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :user_subscription, foreign_key: true
      t.bigint :from_subscription_id
      t.bigint :to_subscription_id
      t.string :change_type, null: false
      t.integer :amount_cents
      t.string :currency
      t.string :billing_provider
      t.string :provider_subscription_id
      t.string :provider_invoice_id
      t.string :idempotency_key
      t.datetime :effective_at
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    # Idempotency: a client-supplied key can only be used once per user.
    add_index :subscription_changes, [:user_id, :idempotency_key],
              unique: true, where: "idempotency_key IS NOT NULL",
              name: "index_subscription_changes_on_user_idempotency"
    # A given Stripe invoice can only complete one change.
    add_index :subscription_changes, :provider_invoice_id,
              unique: true, where: "provider_invoice_id IS NOT NULL",
              name: "index_subscription_changes_on_invoice_id"
    # NOTE: indexes on :user_id and :user_subscription_id are created
    # automatically by t.references above.
  end
end