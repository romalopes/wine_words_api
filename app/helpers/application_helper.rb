module ApplicationHelper
  # Version constants shown in the site footer (kept in sync with the React app).
  # The backend version comes from the VERSION file via config/initializers/app_version.rb,
  # so it stays in sync with what Api::V1::HealthController reports.

  # Helper methods so the footer can access the versions in a view.
  def front_end_version
    FRONT_END_VERSION
  end

  def back_end_version
    BACK_END_VERSION
  end

  # Renders a nav dropdown ("details/summary") with the "All ..." link first
  # (showing the total visible count), followed by one link per enabled
  # category that has at least one linked item.  Category links show the
  # item count, e.g. "News (3)".  Selecting a category navigates to
  # path?category=<name>, which the index actions use to filter the list.
  def nav_dropdown(title, all_label, path, flag, order_column)
    join_model, item_model = case flag
                             when :for_wine then [WineCategory, Wine]
                             when :for_review then [ReviewCategory, Review]
                             when :for_article then [ArticleCategory, Article]
                             end

    is_manager = current_user&.wine_manager?

    # Build the item scope respecting visibility
    item_scope = case flag
                 when :for_wine then Wine.all
                 when :for_review then is_manager ? Review.all : Review.published
                 when :for_article then is_manager ? Article.all : Article.published
                 end

    categories = Category.where(flag => true).order(order_column => :asc, :name => :asc)

    # Count visible items per category via the join table
    counts = join_model
             .joins(item_model.name.underscore.to_sym)
             .merge(item_scope)
             .where(category_id: categories.map(&:id))
             .group(:category_id)
             .count

    total = item_scope.count

    # Count uncategorised items (no join record)
    uncategorised_count = case flag
                          when :for_wine
                            Wine.left_outer_joins(:wine_categories).where(wine_categories: { id: nil }).count
                          when :for_review
                            item_scope.left_outer_joins(:review_categories).where(review_categories: { id: nil }).count
                          when :for_article
                            item_scope.left_outer_joins(:article_categories).where(article_categories: { id: nil }).count
                          end

    links = [link_to("#{all_label} (#{total})", path)] +
            categories
              .select { |c| (counts[c.id] || 0) > 0 }
              .map { |c| link_to("#{c.name} (#{counts[c.id]})", "#{path}?category=#{CGI.escape(c.name)}") }

    # Add Uncategorised link at the end if there are any
    links << link_to("Uncategorised (#{uncategorised_count})", "#{path}?category=Uncategorised") if uncategorised_count > 0

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
  # unordered ones follow alphabetically, "Uncategorised" is always last.
  def category_group_sort(grouped, column)
    order = Category.where.not(column => nil).order(column).pluck(:name, column).to_h
    grouped.sort_by do |name, _|
      if name == "Uncategorised"
        [2, 0, name]
      elsif order.key?(name)
        [0, order[name], name]
      else
        [1, 0, name]
      end
    end
  end
end
