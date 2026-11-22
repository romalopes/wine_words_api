# Invoice email tracking (IDENTITY_214 Phase 12).
#
# Tracks when invoices were emailed to package owners and reminder status.
class AddEmailTrackingToWinePackageInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :wine_package_invoices, :email_sent_at, :datetime
    add_column :wine_package_invoices, :email_send_count, :integer, default: 0, null: false
    add_column :wine_package_invoices, :reminder_sent_at, :datetime

    add_index :wine_package_invoices, :email_sent_at
  end
end
