class AddCountryToGrapes < ActiveRecord::Migration[8.1]
  def change
    add_reference :grapes, :country, foreign_key: true
  end
end
