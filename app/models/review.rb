class Review < ApplicationRecord
  include Imageable
  include Likeable
  include Commentable
  include TextSearchable
  # Issue #185: publication deadlines. Standalone reviews default to creation +
  # 14 days; reviews started from a WinePackage inherit that package's date.
  include Deadlineable

  belongs_to :vintage
  belongs_to :user
  belongs_to :category, optional: true
  has_many :review_categories, dependent: :destroy
  has_many :categories, through: :review_categories
  # Articles this review is linked to. The link (and its per-article status)
  # lives on article_reviews, so the reviews table is untouched.
  has_many :article_reviews, dependent: :destroy
  has_many :articles, through: :article_reviews
  # Package items this review fulfilled. The link is stored once, on
  # wine_package_items.review_id, so the reviews table is untouched and every
  # existing review stays valid. Nullify (not destroy) on deletion.
  has_many :wine_package_items, dependent: :nullify
  has_many :follows, as: :followable, dependent: :destroy
  has_many :followers, through: :follows, source: :user

  STATUSES = %w[draft published archived].freeze
  SOURCES = %w[manual substack wine_front].freeze

  validates :score, presence: true,
                    numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :source, presence: true, inclusion: { in: SOURCES }

  validate :drink_window_is_consistent

  # --- Deadline inheritance (issue #185) ---------------------------------
  #
  # Confirmed priority: explicit > WinePackage > Article > creation + 14 days.
  # The 14-day fallback lives in Deadlineable; these helpers supply the two
  # inherited sources so create paths (and tests) can resolve them before save.
  # The date is copied at creation only — later edits to the package/article
  # never cascade to an existing review.

  # The deadline this review would inherit from its linked sources, in
  # confirmed priority order. Nil when no source carries a date.
  def inherited_deadline
    wine_package_deadline || article_deadline
  end

  # Earliest deadline across the packages this review fulfilled, if any.
  def wine_package_deadline
    wine_package_items.filter_map { |item| item.wine_package&.review_deadline }.min
  end

  # Deadline of the first linked article that carries one.
  def article_deadline
    article_reviews.filter_map { |link| link.article&.deadline }.first
  end


  # Analytics lifecycle: hard-delete events on destroy, soft-exclude on archive.
  after_destroy :purge_analytics_events
  after_update :archive_analytics_events, if: :saved_change_to_status?

  def purge_analytics_events
    Analytics::Event.purge_content!("Review", id)
  end

  def archive_analytics_events
    Analytics::Event.archive_content!("Review", id) if status == "archived"
  end

  before_validation :generate_slug
before_save :update_search_vector, unless: :status_only_update?

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
  scope :archived, -> { where(status: "archived") }
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
    "score_low" => ->(columns, _rank) { "#{columns}score ASC NULLS LAST, #{columns}id DESC" },
    "created_asc" => ->(columns, _rank) { "#{columns}created_at ASC, #{columns}id ASC" },
    "created_desc" => ->(columns, _rank) { "#{columns}created_at DESC, #{columns}id DESC" },
    "updated_asc" => ->(columns, _rank) { "#{columns}updated_at ASC, #{columns}id ASC" },
    "updated_desc" => ->(columns, _rank) { "#{columns}updated_at DESC, #{columns}id DESC" },
    "deadline_asc" => ->(columns, _rank) { "#{columns}deadline ASC NULLS LAST, #{columns}id ASC" },
    "deadline_desc" => ->(columns, _rank) { "#{columns}deadline DESC NULLS LAST, #{columns}id DESC" },
    "title_asc" => ->(columns, _rank) { "#{columns}title ASC, #{columns}id ASC" },
    "title_desc" => ->(columns, _rank) { "#{columns}title DESC, #{columns}id DESC" },
    "published_asc" => ->(columns, _rank) { "#{columns}published_at ASC NULLS LAST, #{columns}id ASC" },
    "published_desc" => ->(columns, _rank) { "#{columns}published_at DESC NULLS LAST, #{columns}id DESC" }
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

  # Advanced, optimised search used by GET /api/v1/reviews (when advanced filters
  # are present) and GET /api/v1/reviews/grouped.
  #
  # Every filter is optional; blank/missing keys are simply ignored. The
  # relation is composed with EXISTS subqueries (rather than joins) so that:
  #   - no review row is ever duplicated (no DISTINCT needed),
  #   - each filter is an independent, skippable predicate,
  #   - the database can use the per-table indexes.
  def self.advanced_search(filters)
    scope = all
    f = filters || {}

    if f[:q].present?
      pattern = "%#{sanitize_sql_like(f[:q].to_s.strip)}%"
      scope = scope.where(
        "reviews.title ILIKE :pattern OR " \
        "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id WHERE v.id = reviews.vintage_id AND w.name ILIKE :pattern) OR " \
        "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id JOIN producers p ON p.id = w.producer_id WHERE v.id = reviews.vintage_id AND p.name ILIKE :pattern) OR " \
        "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id JOIN wine_regions wr ON wr.wine_id = w.id JOIN regions r ON r.id = wr.region_id WHERE v.id = reviews.vintage_id AND r.name ILIKE :pattern) OR " \
        "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id JOIN wine_grapes wg ON wg.wine_id = w.id JOIN grapes g ON g.id = wg.grape_id WHERE v.id = reviews.vintage_id AND g.name ILIKE :pattern)",
        pattern: pattern
      )
    end

    if f[:name].present?
      scope = scope.where("reviews.title ILIKE ?", "%#{sanitize_sql_like(f[:name])}%")
    end

    if f[:producer_name].present?
      scope = scope.joins(vintage: { wine: :producer })
                   .where("producers.name ILIKE ?", "%#{sanitize_sql_like(f[:producer_name])}%")
    end

    scope = scope.where(color: f[:color]) if f[:color].present?
    scope = scope.where(closure: f[:closure]) if f[:closure].present?
    scope = scope.where(sparkling: f[:sparkling]) unless f[:sparkling].nil?
    scope = scope.where(fortified: f[:fortified]) unless f[:fortified].nil?

    if f[:country_id].present?
      scope = scope.joins(vintage: { wine: :producer })
                   .where(producers: { country_id: f[:country_id] })
    end

    if f[:region_ids].present?
      scope = scope.where(
        "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id JOIN wine_regions wr ON wr.wine_id = w.id WHERE v.id = reviews.vintage_id AND wr.region_id IN (?))",
        f[:region_ids]
      )
    end

    if f[:grape_ids].present?
      scope = scope.where(
        "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id JOIN wine_grapes wg ON wg.wine_id = w.id WHERE v.id = reviews.vintage_id AND wg.grape_id IN (?))",
        f[:grape_ids]
      )
    end

    # Alcohol percentage range on the wine.
    if f[:alcohol_min].present? || f[:alcohol_max].present?
      conds = []
      args  = []
      if f[:alcohol_min].present?
        conds << "wines.alcohol_percentage >= ?"
        args << f[:alcohol_min]
      end
      if f[:alcohol_max].present?
        conds << "wines.alcohol_percentage <= ?"
        args << f[:alcohol_max]
      end
      scope = scope.where(
        "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id WHERE v.id = reviews.vintage_id AND #{conds.join(' AND ')})",
        *args
      )
    end

    # Vintage year and/or price range across the wine's vintages.
    vintage_filters = %i[vintage_year_min vintage_year_max price_min price_max]
    if vintage_filters.any? { |k| f[k].present? }
      conds = ["vintages.wine_id = reviews.vintage_id"]
      args  = []
      conds << "vintages.year >= ?"         if f[:vintage_year_min].present?
      args  << f[:vintage_year_min]         if f[:vintage_year_min].present?
      conds << "vintages.year <= ?"         if f[:vintage_year_max].present?
      args  << f[:vintage_year_max]         if f[:vintage_year_max].present?
      if f[:price_min].present?
        conds << "vintages.price_cents >= ?"
        args << (f[:price_min].to_f * 100).round
      end
      if f[:price_max].present?
        conds << "vintages.price_cents <= ?"
        args << (f[:price_max].to_f * 100).round
      end
      scope = scope.where(
        "EXISTS (SELECT 1 FROM vintages v WHERE v.id = reviews.vintage_id AND #{conds.join(' AND ')})",
        *args
      )
    end

    # Score range on the review itself.
    if f[:score_min].present? || f[:score_max].present?
      conds = []
      args  = []
      conds << "reviews.score >= ?" if f[:score_min].present?
      args  << f[:score_min]        if f[:score_min].present?
      conds << "reviews.score <= ?" if f[:score_max].present?
      args  << f[:score_max]        if f[:score_max].present?
      scope = scope.where(conds.join(" AND "), *args)
    end

    # Published date range on the review.
    if f[:published_from].present? || f[:published_to].present?
      conds = []
      args  = []
      conds << "reviews.published_at >= ?" if f[:published_from].present?
      args  << f[:published_from]          if f[:published_from].present?
      conds << "reviews.published_at <= ?" if f[:published_to].present?
      args  << f[:published_to]            if f[:published_to].present?
      scope = scope.where(conds.join(" AND "), *args)
    end

    # Drink window range on the review.
    if f[:drink_from_min].present? || f[:drink_from_max].present?
      conds = []
      args  = []
      conds << "reviews.drink_from >= ?" if f[:drink_from_min].present?
      args  << f[:drink_from_min]        if f[:drink_from_min].present?
      conds << "reviews.drink_from <= ?" if f[:drink_from_max].present?
      args  << f[:drink_from_max]        if f[:drink_from_max].present?
      scope = scope.where(conds.join(" AND "), *args)
    end

    if f[:drink_to_min].present? || f[:drink_to_max].present?
      conds = []
      args  = []
      conds << "reviews.drink_to >= ?" if f[:drink_to_min].present?
      args  << f[:drink_to_min]        if f[:drink_to_min].present?
      conds << "reviews.drink_to <= ?" if f[:drink_to_max].present?
      args  << f[:drink_to_max]        if f[:drink_to_max].present?
      scope = scope.where(conds.join(" AND "), *args)
    end

    # Taste parameter ranges (review-level filters on vintage's taste parameters)
    if f[:taste_parameters].present?
      f[:taste_parameters].each do |slug, range|
        next unless range.is_a?(Hash) && (range[:min].present? || range[:max].present?)
        next if range[:min].to_i <= 0 && range[:max].to_i >= 10

        conds = ["vintages.wine_id = reviews.vintage_id AND wine_taste_parameters.slug = ?"]
        args  = [slug]
        conds << "wine_taste_parameters.score >= ?" if range[:min].present? && range[:min].to_i > 0
        args  << range[:min].to_i                    if range[:min].present? && range[:min].to_i > 0
        conds << "wine_taste_parameters.score <= ?" if range[:max].present? && range[:max].to_i < 10
        args  << range[:max].to_i                    if range[:max].present? && range[:max].to_i < 10

        scope = scope.where(
          "EXISTS (SELECT 1 FROM vintages v JOIN wines w ON w.id = v.wine_id JOIN wine_taste_parameters wtp ON wtp.wine_id = w.id WHERE v.id = reviews.vintage_id AND #{conds.join(' AND ')})",
          *args
        )
      end
    end

    scope
  end


  private

  def status_only_update?
    persisted? && (changes_to_save.keys - %w[status published_at updated_at]).empty?
  end

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
