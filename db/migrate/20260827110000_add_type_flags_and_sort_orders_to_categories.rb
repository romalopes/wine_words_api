class AddTypeFlagsAndSortOrdersToCategories < ActiveRecord::Migration[7.1]
  class MigrationAddTypeFlagsAndSortOrdersToCategories < ActiveRecord::Base
    self.table_name = "categories"
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

    MigrationAddTypeFlagsAndSortOrdersToCategories.reset_column_information

    MigrationAddTypeFlagsAndSortOrdersToCategories.create(name: "Tastings", slug: "tastings") unless MigrationAddTypeFlagsAndSortOrdersToCategories.find_by(name: "Tastings") # TASTINGS
    MigrationAddTypeFlagsAndSortOrdersToCategories.create(name: "Australian Icons", slug: "australian-icons") unless MigrationAddTypeFlagsAndSortOrdersToCategories.find_by(name: "Australian Icons")
    MigrationAddTypeFlagsAndSortOrdersToCategories.create(name: "Interviews", slug: "interviews") unless MigrationAddTypeFlagsAndSortOrdersToCategories.find_by(name: "Interviews")
    MigrationAddTypeFlagsAndSortOrdersToCategories.create(name: "Australian Chardonnay | Best Reviewed", slug: "australian-chardonnay-best-reviewed") unless MigrationAddTypeFlagsAndSortOrdersToCategories.find_by(name: "Australian Chardonnay | Best Reviewed")
    MigrationAddTypeFlagsAndSortOrdersToCategories.create(name: "Eno Travel", slug: "eno-travel") unless MigrationAddTypeFlagsAndSortOrdersToCategories.find_by(name: "Eno Travel")
    MigrationAddTypeFlagsAndSortOrdersToCategories.create(name: "Regional Tastings", slug: "regional-tastings") unless MigrationAddTypeFlagsAndSortOrdersToCategories.find_by(name: "Regional Tastings")
    MigrationAddTypeFlagsAndSortOrdersToCategories.create(name: "Producer Spotlight", slug: "producer-spotlight") unless MigrationAddTypeFlagsAndSortOrdersToCategories.find_by(name: "Producer Spotlight")

    # Existing categories were article categories; give them incremental
    # sort orders in their current order of existence.
    MigrationAddTypeFlagsAndSortOrdersToCategories.order(:id).each_with_index do |category, index|
      MigrationAddTypeFlagsAndSortOrdersToCategories.update_columns(
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