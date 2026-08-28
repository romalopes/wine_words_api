module ApplicationHelper
  # Renders a nav dropdown ("details/summary") with the "All ..." link first,
  # followed by one link per enabled category, in admin-defined sort order.
  # Selecting a category navigates to path?category=<name>, which the index
  # actions use to filter the list.
  def nav_dropdown(title, all_label, path, flag, order_column)
    categories = Category.where(flag => true).order(order_column => :asc, :name => :asc)
    links = [link_to(all_label, path)] +
            categories.map { |c| link_to(c.name, "#{path}?category=#{CGI.escape(c.name)}") }
    content_tag(:details, class: "site-nav__settings site-nav__category-menu") do
      safe_join(
        [
          content_tag(:summary, title),
          content_tag(:div, safe_join(links), class: "site-nav__settings-menu"),
        ]
      )
    end
  end

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
