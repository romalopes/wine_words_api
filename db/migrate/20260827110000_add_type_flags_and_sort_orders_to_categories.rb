class AddTypeFlagsAndSortOrdersToCategories < ActiveRecord::Migration[7.1]
  def up
    change_table :categories do |t|
      t.boolean :for_wine, default: false, null: false
      t.boolean :for_article, default: false, null: false
      t.boolean :for_review, default: false, null: false
      t.integer :sort_order_wine
      t.integer :sort_order_review
      t.integer :sort_order_article
    end

    # Existing categories were article categories; give them incremental
    # sort orders in their current order of existence.
    Category.order(:id).each_with_index do |category, index|
      category.update_columns(
        for_article: true,
        sort_order_wine: index + 1,
        sort_order_review: index + 1,
        sort_order_article: index + 1
      )
    end
  end

  def down
    remove_columns :categories, :for_wine, :for_article, :for_review,
                   :sort_order_wine, :sort_order_review, :sort_order_article
  end
end