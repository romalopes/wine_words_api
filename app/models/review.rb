class Review < ApplicationRecord
  include Imageable
  include Likeable
  include Commentable
  include TextSearchable

  belongs_to :vintage
  belongs_to :user
  belongs_to :category, optional: true
  has_many :review_categories, dependent: :destroy
  has_many :categories, through: :review_categories
  # Package items this review fulfilled. The link is stored once, on
  # wine_package_items.review_id, so the reviews table is untouched and every
  # existing review stays valid. Nullify (not destroy) on deletion.
  has_many :wine_package_items, dependent: :nullify

  validates :score, presence: true,
                    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :status, presence: true, inclusion: { in: %w[draft published] }
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :source, presence: true, inclusion: { in: %w[manual substack wine_front] }

  validate :drink_window_is_consistent

  before_validation :generate_slug
before_save :update_search_vector

  # Use slug instead of numeric id in URLs so lookups resolve via find_by!(slug:)
  def to_param
    slug
  end

  def drink_window_is_consistent
    return unless drink_from.present? || drink_to.present?

    if drink_from.present? && drink_from < (vintage&.year || 0)
      errors.add(:drink_from, "cannot be earlier than the vintage year")
    end
    if drink_from.present? && drink_to.present? && drink_to < drink_from
      errors.add(:drink_to, "cannot be earlier than Drink From")
    end
    if drink_to.present? && drink_from.blank?
      errors.add(:drink_from, "is required when Drink To is set")
    end
  end

  scope :published, -> { where(status: "published") }
  scope :drafts, -> { where(status: "draft") }
  scope :visible_to, ->(user) { where(status: "published").or(where(user: user)) }
  scope :by_recency, -> { order(created_at: :desc) }

  # Whitelisted `sort` values for the reviews listing (see TextSearchable).
  # Each lambda receives the column qualifier to prefix its columns with and the
  # relevance expression, so the same whitelist orders the flat feed
  # (`reviews.`) and the grouped window function (`r.` subquery alias).
  SORT_ORDERS = {
    "relevance" => ->(columns, rank) { "#{rank} DESC NULLS LAST, #{columns}id DESC" },
    "recent" => ->(columns, _rank) { "#{columns}created_at DESC, #{columns}id DESC" },
    "oldest" => ->(columns, _rank) { "#{columns}created_at ASC, #{columns}id ASC" },
    "score_high" => ->(columns, _rank) { "#{columns}score DESC NULLS LAST, #{columns}id DESC" },
    "score_low" => ->(columns, _rank) { "#{columns}score ASC NULLS LAST, #{columns}id DESC" }
  }.freeze

  # Keep article-review links consistent when a review is unpublished.
  after_save :demote_article_links, if: :saved_change_to_status?

  # A published (or unpublished) review changes whether the package item(s) it
  # fulfilled are done, which may complete — or reopen — the package. Only
  # reviews referenced by an item participate; reviews created directly on a
  # vintage are unaffected.
  after_save :reconcile_wine_package, if: :saved_change_to_status?

  private

  def reconcile_wine_package
    WinePackageItem.where(review_id: id).includes(:wine_package).find_each do |item|
      WinePackages::CheckCompletion.call(item.wine_package)
    end
  end

  def generate_slug
    return if slug.present? && !title_changed?
    return if title.blank?

    base = title.to_s.parameterize.presence || "review"
    candidate = base
    i = 2
    while self.class.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{i}"
      i += 1
    end
    self.slug = candidate
  end

  def demote_article_links
    return if status == "published"

    ArticleReview.where(review: self, status: "published").update_all(status: "draft")
  end

  private

  def update_search_vector
    self.searchable = self.class.connection.select_value(search_vector_sql)
  end

  # A = title, wine_name
  # B = producer, content, vintage year
  # C = region, grape
  # D = country, author
  #
  # The vintage year is indexed as text so `2021` finds a 2021 wine even when
  # the year appears nowhere in the title or tasting note.
  #
  # `searchable` is a Postgres tsvector. `to_tsvector`/`setweight`/`coalesce`
  # only exist in the database, so the expression is evaluated server-side —
  # which also means an unsaved record (no row to select from) works, because
  # every value is interpolated rather than read from the table.
  def search_vector_sql
    wine_name = vintage&.wine&.name
    producer_name = vintage&.wine&.producer&.name
    region_name = vintage&.wine&.regions&.first&.name
    grape_name = vintage&.wine&.grapes&.first&.name
    country_name = vintage&.wine&.regions&.first&.country&.name
    vintage_year = vintage&.year.to_s
    author_name = user&.display_name || user&.email

    <<~SQL
      SELECT
        setweight(to_tsvector('english', coalesce(#{sql_quote(title)}, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(wine_name)}, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(producer_name)}, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(comment)}, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(vintage_year)}, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(region_name)}, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(grape_name)}, '')), 'C') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(country_name)}, '')), 'D') ||
        setweight(to_tsvector('english', coalesce(#{sql_quote(author_name)}, '')), 'D')
    SQL
  end
end
