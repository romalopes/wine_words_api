class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :first_name, limit: 80
      t.string :last_name, limit: 80
      t.string :phone, limit: 40
      t.date :date_of_birth

      t.timestamps
    end

    create_table :account_addresses do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :street_address, limit: 200
      t.string :city, limit: 100
      t.string :state, limit: 100
      t.string :postal_code, limit: 20
      t.references :country, null: true, foreign_key: { to_table: :countries }

      t.timestamps
    end
  end
end
