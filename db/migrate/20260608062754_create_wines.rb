class CreateWines < ActiveRecord::Migration[8.1]
  def change
    create_table :wines do |t|
      t.string :identification
      t.string :name
      t.string :region
      t.string :color
      t.text :prompt

      t.timestamps
    end
  end
end
