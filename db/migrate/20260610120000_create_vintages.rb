class CreateVintages < ActiveRecord::Migration[6.1]
  def change
    create_table :vintages do |t|
      t.references :wine, foreign_key: true
      t.integer :year, null: false
      t.text :prompt
      t.timestamps
    end

    add_column :wines, :closure, :string
    add_column :wines, :alcohol_percentage, :decimal, precision: 10, scale: 2
    add_column :wines, :volume_ml, :integer
  end
end
