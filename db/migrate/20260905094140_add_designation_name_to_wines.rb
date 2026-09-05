class AddDesignationNameToWines < ActiveRecord::Migration[8.1]
  def change
    add_column :wines, :designation_name, :string
  end
end
