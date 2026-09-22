class AddSlugToReviewsAndArticles < ActiveRecord::Migration[7.1]
  def up
    add_column :reviews, :slug, :string

    # Backfill existing reviews using the model's generate_slug logic. Reviews
    # with a blank title produce no slug there — fall back to a stable,
    # unique id-based slug so the NOT NULL constraint can be applied.
    Review.reset_column_information
    Review.find_each do |review|
      review.send(:generate_slug)
      review.slug ||= "review-#{review.id}"
      review.update_columns(slug: review.slug)
    end

    # Uniqueness + NOT NULL only AFTER the backfill: existing rows still have
    # NULL slugs when the column is first added.
    add_index :reviews, :slug, unique: true
    change_column_null :reviews, :slug, false

    add_column :articles, :slug, :string

    # Backfill existing articles using the model's generate_slug logic, with
    # the same id-based fallback for articles without a usable title.
    Article.reset_column_information
    Article.find_each do |article|
      article.send(:generate_slug)
      article.slug ||= "article-#{article.id}"
      article.update_columns(slug: article.slug)
    end

    add_index :articles, :slug, unique: true
    change_column_null :articles, :slug, false
  end

  def down
    remove_column :reviews, :slug
    remove_column :articles, :slug
  end
end
