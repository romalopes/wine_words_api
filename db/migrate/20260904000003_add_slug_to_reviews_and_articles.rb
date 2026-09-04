class AddSlugToReviewsAndArticles < ActiveRecord::Migration[7.1]
  def up
    add_column :reviews, :slug, :string
    add_index :reviews, :slug, unique: true

    # Backfill existing reviews using the model's generate_slug logic.
    Review.reset_column_information
    Review.find_each do |review|
      review.send(:generate_slug)
      review.update_columns(slug: review.slug)
    end

    change_column_null :reviews, :slug, false

    add_column :articles, :slug, :string
    add_index :articles, :slug, unique: true

    # Backfill existing articles using the model's generate_slug logic.
    Article.reset_column_information
    Article.find_each do |article|
      article.send(:generate_slug)
      article.update_columns(slug: article.slug)
    end

    change_column_null :articles, :slug, false
  end

  def down
    remove_column :reviews, :slug
    remove_column :articles, :slug
  end
end
