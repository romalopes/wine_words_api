class Article < ApplicationRecord
  include Imageable

  belongs_to :user
  belongs_to :category, optional: true
  has_many :article_categories, dependent: :destroy
  has_many :categories, through: :article_categories

  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  # Articles link to vintages directly; the relationship to wines goes
  # through those vintages.
  has_many :article_vintages, dependent: :destroy
  has_many :vintages, through: :article_vintages
  has_many :wines, through: :vintages

  has_many :article_producers, dependent: :destroy
  has_many :producers, through: :article_producers

  has_many :article_reviews, dependent: :destroy
  has_many :reviews, through: :article_reviews

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[draft published] }

  before_validation :generate_slug
before_save :update_search_vector

  # Use slug instead of numeric id in URLs so lookups resolve via find_by!(slug:)
  def to_param
    slug
  end

  scope :published, -> { where(status: "published") }
  scope :drafts, -> { where(status: "draft") }
  scope :visible_to, ->(user) { published.or(where(user: user)) }
  scope :recent, -> { order(created_at: :desc) }

  # Reviews shown at the bottom of the article page.
  def published_reviews
    reviews.where(article_reviews: { status: "published" })
  end

  private

  def generate_slug
    return if slug.present? && !title_changed?
    return if title.blank?

    base = title.to_s.parameterize.presence || "article"
    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end
private

  def update_search_vector
    tag_names = tags.pluck(:name).join(' ')
    category_name = category&.name
    author_name = user&.user_name || user&.email

    # `searchable` is a Postgres tsvector. `to_tsvector`/`setweight`/`coalesce`
    # only exist in the database, so the expression is evaluated server-side and
    # the resulting tsvector is stored on the record.
    self.searchable = self.class.connection.select_value(<<~SQL)
      SELECT
        setweight(to_tsvector('english', coalesce(#{sql_quote(title)}, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(abstract)}, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(body)}, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(tag_names)}, '')), 'D') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(category_name)}, '')), 'D') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(author_name)}, '')), 'D')
    SQL
  end

  def sql_quote(value)
    self.class.connection.quote(value)
  end
end