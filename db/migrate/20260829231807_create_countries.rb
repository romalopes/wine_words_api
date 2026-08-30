class CreateCountries < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.string :name
      t.string :code
      t.string :continent
      t.string :flag_emoji

      t.timestamps
    end
    add_index :countries, :name, unique: true
    add_index :countries, :code, unique: true
  end
end
