module ApplicationHelper
  # Sorts grouped-by-category-name hashes by the stored sort order for the
  # given column (e.g. :sort_order_wine). Ordered categories come first,
  # unordered ones follow alphabetically, "Uncategorized" is always last.
  def category_group_sort(grouped, column)
    order = Category.where.not(column => nil).order(column).pluck(:name, column).to_h
    grouped.sort_by do |name, _|
      if name == "Uncategorized"
        [2, 0, name]
      elsif order.key?(name)
        [0, order[name], name]
      else
        [1, 0, name]
      end
    end
  end
end
