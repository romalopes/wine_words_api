class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.string  :name,        null: false
      t.string  :slug,        null: false
      t.text    :description
      t.boolean :popular,     default: false, null: false
      t.boolean :visible,     default: true,  null: false
      t.boolean :active,      default: true,  null: false
      t.boolean :is_default,  default: false, null: false
      t.integer :position,    default: 0,     null: false
      t.integer :monthly_price_cents
      t.integer :yearly_price_cents
      t.string  :currency,    default: "AUD", null: false

      t.timestamps
    end
    add_index :subscriptions, :name,   unique: true
    add_index :subscriptions, :slug,   unique: true
    add_index :subscriptions, :is_default, unique: true, where: "is_default = true"

    create_table :subscription_features do |t|
      t.string  :name,        null: false
      t.string  :slug,        null: false
      t.text    :description

      t.timestamps
    end
    add_index :subscription_features, :slug, unique: true

    create_table :subscription_subscription_features do |t|
      t.references :subscription,        null: false, foreign_key: true
      t.references :subscription_feature, null: false, foreign_key: true
      t.integer    :position,            default: 0, null: false

      t.timestamps
    end
    add_index :subscription_subscription_features,
              [:subscription_id, :subscription_feature_id],
              unique: true, name: "index_sub_sub_features_on_sub_and_feature"

    create_table :user_subscriptions do |t|
      t.references :user,         null: false, foreign_key: true
      t.references :subscription, null: false, foreign_key: true
      t.datetime   :started_at,   null: false
      t.datetime   :ended_at
      t.datetime   :cancelled_at
      t.string     :status,       default: "active", null: false

      t.timestamps
    end
    add_index :user_subscriptions, [:user_id, :status]

    add_reference :users, :subscription, foreign_key: true
  end
end