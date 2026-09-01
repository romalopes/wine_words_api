class AddProducerDetails < ActiveRecord::Migration[7.1]
  def change
    add_column :producers, :legal_name, :string
    add_column :producers, :phone, :string
    add_column :producers, :city, :string
    add_column :producers, :state, :string
    add_column :producers, :postal_code, :string
    add_column :producers, :founded_year, :integer
    add_column :producers, :active, :boolean, default: true, null: false
    add_column :producers, :country_id, :bigint

    create_table :producer_regions do |t|
      t.references :producer, null: false, foreign_key: true
      t.references :region, null: false, foreign_key: true
      t.timestamps
    end
    add_index :producer_regions, %i[producer_id region_id], unique: true

    create_table :producer_grapes do |t|
      t.references :producer, null: false, foreign_key: true
      t.references :grape, null: false, foreign_key: true
      t.timestamps
    end
    add_index :producer_grapes, %i[producer_id grape_id], unique: true
  end
end
