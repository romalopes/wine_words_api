class AddPriceAndNoVintageToVintagesAndDrinkWindowToReviews < ActiveRecord::Migration[7.1]
  def change
    change_table :vintages do |t|
      t.decimal :price, precision: 10, scale: 2
      t.boolean :no_vintage, default: false, null: false
    end

    change_table :reviews do |t|
      t.integer :drink_from
      t.integer :drink_to
      t.boolean :drink_plus, default: false, null: false
    end
  end
end