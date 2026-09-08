class BackfillExistingUsersSubscriptions < ActiveRecord::Migration[8.1]
  def up
    # Idempotent backfill: existing users with no subscription history are
    # assigned the default FREE plan and given an initial history record.
    default_sub = Subscription.find_by(is_default: true)
    return unless default_sub

    User.find_each do |user|
      next if user.user_subscriptions.exists?

      user.update_columns(
        subscription_id: user.subscription_id || default_sub.id
      )
      user.user_subscriptions.create!(
        subscription: default_sub,
        started_at: user.created_at || Time.current,
        status: :active,
        billing_provider: "manual"
      )
    end
  end

  def down
    # Data backfill is non-destructive to reverse automatically.
    raise ActiveRecord::IrreversibleMigration
  end
end
