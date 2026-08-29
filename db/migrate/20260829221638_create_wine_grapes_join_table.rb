class CreateWineGrapesJoinTable < ActiveRecord::Migration[8.1]
  def change
    create_table :wine_grapes do |t|
      t.references :wine, null: false, foreign_key: true
      t.references :grape, null: false, foreign_key: true
      t.timestamps
    end
    add_index :wine_grapes, [:wine_id, :grape_id], unique: true
  end
end
