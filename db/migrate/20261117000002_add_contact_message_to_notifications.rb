# Contact-message notifications (IDENTITY_209 Phase 2).
#
# The existing package-notification unique index only covers rows with a
# wine_package_id (PostgreSQL treats NULLs as distinct), so contact-message
# notifications need their own dedup guarantee. The partial unique index makes
# "one delivery per recipient per contact message per type" a database rule,
# which is what makes retried NotifyStaff jobs safe.
class AddContactMessageToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_reference :notifications, :contact_message, foreign_key: true

    add_index :notifications,
              [ :recipient_id, :contact_message_id, :notification_type ],
              unique: true,
              where: "contact_message_id IS NOT NULL",
              name: "index_notifications_on_recipient_and_contact_message"
  end
end
