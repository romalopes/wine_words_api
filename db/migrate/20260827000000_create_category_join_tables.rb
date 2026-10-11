class CreateCategoryJoinTables < ActiveRecord::Migration[7.0]
  def up
    { wine_categories: :wine, review_categories: :review, article_categories: :article }.each do |table, owner|
      # Restored databases can contain these tables without this migration version.
      # Preserve their rows while completing the indexes and foreign keys below.
      unless table_exists?(table)
        create_table table do |t|
          t.references owner, null: false, foreign_key: true
          t.references :category, null: false, foreign_key: true
          t.timestamps
        end
      end

      [owner, :category].each do |reference|
        column = "#{reference}_id"
        add_index table, column unless index_exists?(table, column)
        target = reference.to_s.pluralize.to_sym
        add_foreign_key table, target, column: column unless foreign_key_exists?(table, target, column: column)
      end

      columns = ["#{owner}_id", "category_id"]
      add_index table, columns, unique: true unless index_exists?(table, columns, unique: true)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Category join tables may predate this migration; dropping them would lose existing data."
  end
end
