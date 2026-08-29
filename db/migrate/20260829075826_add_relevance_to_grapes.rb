class AddRelevanceToGrapes < ActiveRecord::Migration[8.1]
  def change
    add_column :grapes, :relevance, :integer
  end
end
