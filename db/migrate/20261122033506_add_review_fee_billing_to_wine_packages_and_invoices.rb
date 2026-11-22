# Wine Words review fee billing (IDENTITY_214).
#
# Adds package-level estimate snapshot and extends wine_package_invoices with
# manual-billing fields. Existing Stripe-owned invoices get payment_source="stripe"
# backfill. All new columns are nullable to avoid backfill of historical data.
class AddReviewFeeBillingToWinePackagesAndInvoices < ActiveRecord::Migration[8.1]
  def change
    # --- wine_packages: submission estimate snapshot ---
    add_column :wine_packages, :estimated_bottle_count, :integer
    add_column :wine_packages, :estimated_unit_fee, :decimal, precision: 10, scale: 2
    add_column :wine_packages, :estimated_currency, :string, limit: 8
    add_column :wine_packages, :estimated_total, :decimal, precision: 10, scale: 2
    add_column :wine_packages, :estimate_snapshot_at, :datetime
    add_column :wine_packages, :billable_bottle_count, :integer
    add_column :wine_packages, :billable_confirmed_by_id, :bigint
    add_column :wine_packages, :billable_confirmed_at, :datetime

    # FK for billable_confirmed_by_id (staff user who confirmed)
    add_foreign_key :wine_packages, :users, column: :billable_confirmed_by_id

    # --- wine_package_invoices: manual billing extensions ---
    add_column :wine_package_invoices, :payment_source, :string, limit: 16, default: "stripe", null: false
    add_column :wine_package_invoices, :billable_bottle_count, :integer
    add_column :wine_package_invoices, :unit_fee, :decimal, precision: 10, scale: 2
    add_column :wine_package_invoices, :recorded_by_id, :bigint
    add_column :wine_package_invoices, :recorded_at, :datetime
    add_column :wine_package_invoices, :cancellation_reason, :string, limit: 255
    add_column :wine_package_invoices, :notes, :text

    # FK for recorded_by_id (staff user who recorded the invoice)
    add_foreign_key :wine_package_invoices, :users, column: :recorded_by_id

    # Indexes
    add_index :wine_package_invoices, :payment_source
    add_index :wine_package_invoices, :recorded_by_id

    # Backfill existing invoices with payment_source = "stripe"
    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE wine_package_invoices
          SET payment_source = 'stripe'
          WHERE payment_source IS NULL OR payment_source = ''
        SQL
      end
    end
  end
end
