class CreateAccountInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :account_status, :string, null: false, default: "active"
    add_index :users, :account_status
    add_check_constraint :users,
                         "account_status IN ('unclaimed', 'active', 'suspended')",
                         name: "users_account_status_check"

    change_column_null :users, :email, true
    change_column_default :users, :email, from: "", to: nil
    remove_index :users, :email
    add_index :users, "LOWER(email)", unique: true, name: "index_users_on_lower_email"

    create_table :account_invitations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :email, null: false
      t.string :token_digest, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :sent_at
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.references :revoked_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :delivery_status
      t.string :delivery_error_code
      t.string :provider_message_id
      t.datetime :last_delivery_attempt_at

      t.timestamps
    end

    add_index :account_invitations, :token_digest, unique: true
    add_index :account_invitations, [ :user_id, :created_at ]
    add_index :account_invitations, :status
    add_check_constraint :account_invitations,
                         "status IN ('pending', 'sent', 'accepted', 'revoked')",
                         name: "account_invitations_status_check"
  end
end
