class CreateProducerMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :producer_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :producer, null: false, foreign_key: true
      t.references :created_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :producer_memberships, [:user_id, :producer_id], unique: true
  end
end
