class Review < ApplicationRecord
  include Imageable

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

  validate :drink_window_is_consistent

  before_validation :generate_slug

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
end
