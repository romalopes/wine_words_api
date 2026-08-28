class AddTypeFlagsAndSortOrdersToCategories < ActiveRecord::Migration[7.1]
  class MigrationAddTypeFlagsAndSortOrdersToCategories < ActiveRecord::Base
    self.table_name = "producers"
  end

  def up
    change_table :categories do |t|
      t.boolean :for_wine, default: false, null: false
      t.boolean :for_article, default: false, null: false
      t.boolean :for_review, default: false, null: false
      t.integer :sort_order_wine
      t.integer :sort_order_review
      t.integer :sort_order_article
    end

    MigrationProducer.reset_column_information

    Category.create(name: "Tastings", slug: "tastings") unless Category.find_by(name: "Tastings") # TASTINGS
    Category.create(name: "Australian Icons", slug: "australian-icons") unless Category.find_by(name: "Australian Icons")
    Category.create(name: "Interviews", slug: "interviews") unless Category.find_by(name: "Interviews")
    Category.create(name: "Australian Chardonnay | Best Reviewed", slug: "australian-chardonnay-best-reviewed") unless Category.find_by(name: "Australian Chardonnay | Best Reviewed")
    Category.create(name: "Eno Travel", slug: "eno-travel") unless Category.find_by(name: "Eno Travel")
    Category.create(name: "Regional Tastings", slug: "regional-tastings") unless Category.find_by(name: "Regional Tastings")
    Category.create(name: "Producer Spotlight", slug: "producer-spotlight") unless Category.find_by(name: "Producer Spotlight")

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