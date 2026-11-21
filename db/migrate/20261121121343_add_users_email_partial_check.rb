class AddUsersEmailPartialCheck < ActiveRecord::Migration[8.1]
  def change
    # email is required when account_status != 'unclaimed'
    execute <<-SQL
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'users_email_required_when_claimed'
        ) THEN
          ALTER TABLE users
          ADD CONSTRAINT users_email_required_when_claimed
          CHECK (account_status = 'unclaimed' OR email IS NOT NULL);
        END IF;
      END $$;
    SQL
  end
end
