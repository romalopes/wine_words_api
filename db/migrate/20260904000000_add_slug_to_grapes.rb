class AddSlugToGrapes < ActiveRecord::Migration[7.1]
  def up
    add_column :grapes, :slug, :string
    add_index :grapes, :slug, unique: true

    # Backfill existing grapes using the model's generate_slug logic.
    Grape.reset_column_information
    Grape.find_each do |grape|
      grape.send(:generate_slug)
      grape.update_columns(slug: grape.slug)
    end

    change_column_null :grapes, :slug, false
  end

  def down
    remove_column :grapes, :slug
  end
end
