class AddBillingFieldsToUserSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :user_subscriptions, :billing_provider, :string, default: "manual", null: false
    add_column :user_subscriptions, :provider_subscription_id, :string
  end
end
