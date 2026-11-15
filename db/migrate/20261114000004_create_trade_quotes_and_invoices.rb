# Trade portal commercial workflow (IDENTITY_206 Phase 10): quotes and
# invoices. Two tables only — package/quote/invoice status transitions live on
# the existing wine_packages.status enum and WinePackageEvent audit trail.
class CreateTradeQuotesAndInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :wine_package_quotes do |t|
      t.references :wine_package, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }, null: false
      t.string :service_type, limit: 32, null: false, default: "review"
      t.jsonb :items, null: false, default: []
      t.string :currency, limit: 8, null: false, default: "EUR"
      t.decimal :subtotal, precision: 10, scale: 2, null: false, default: 0
      t.decimal :tax, precision: 10, scale: 2, null: false, default: 0
      t.decimal :total, precision: 10, scale: 2, null: false, default: 0
      t.string :status, limit: 32, null: false, default: "draft"
      t.date :valid_until

      t.timestamps
    end

    create_table :wine_package_invoices do |t|
      t.references :wine_package, null: false, foreign_key: true
      t.references :wine_package_quote, foreign_key: true
      t.string :invoice_number, null: false
      t.string :currency, limit: 8, null: false, default: "EUR"
      t.jsonb :items, null: false, default: []
      t.decimal :subtotal, precision: 10, scale: 2, null: false, default: 0
      t.decimal :tax, precision: 10, scale: 2, null: false, default: 0
      t.decimal :total, precision: 10, scale: 2, null: false, default: 0
      t.string :status, limit: 32, null: false, default: "draft"
      t.datetime :issued_at
      t.datetime :due_at
      t.datetime :paid_at

      # Stripe (Phase 11) — metadata kept for reconciliation; idempotency of the
      # WEBHOOK is handled by BillingEvent.claim (existing), not duplicated here.
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.jsonb :stripe_payment_metadata

      t.timestamps
    end

    add_index :wine_package_invoices, :invoice_number, unique: true
    add_index :wine_package_invoices, :stripe_checkout_session_id
    add_index :wine_package_invoices, :status
    add_index :wine_package_quotes, :status
  end
end