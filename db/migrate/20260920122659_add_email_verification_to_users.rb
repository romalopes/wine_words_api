class AddEmailVerificationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verified_at, :datetime
    add_column :users, :email_verification_token_digest, :string
    add_column :users, :email_verification_sent_at, :datetime
    add_index :users, :email_verification_token_digest
  end
end
