class CreateWineries < ActiveRecord::Migration[8.1]
  def change
    create_table :wineries do |t|
      t.string :name
      t.string :address
      t.string :email
      t.string :slug

      t.timestamps
    end

    add_index :wineries, :slug, unique: true
    add_index :wineries, :name, unique: true
  end
end