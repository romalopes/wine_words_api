# Public contact form inbox (IDENTITY_209).
#
# One row per submission from the anonymous Contact page. The message body is
# stored as plain text and rendered escaped everywhere (never HTML). Status is
# a single small state machine (unread/read/archived) with matching timestamps,
# so the inbox can filter without extra joins.
class CreateContactMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :contact_messages do |t|
      t.string :name, limit: 120, null: false
      t.string :email, limit: 254, null: false
      t.string :contact_type, limit: 32, null: false
      t.string :subject, limit: 180, null: false
      t.text :message, null: false
      t.string :status, limit: 16, null: false, default: "unread"
      t.datetime :read_at
      t.datetime :archived_at

      t.timestamps
    end

    # Inbox queries: status tabs, type filter, newest-first ordering and the
    # composite tab+date scan.
    add_index :contact_messages, :status
    add_index :contact_messages, :contact_type
    add_index :contact_messages, :created_at
    add_index :contact_messages, [ :status, :created_at ]
  end
end
