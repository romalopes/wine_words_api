# One line in a WinePackage: a wine (resolved to a Vintage when the catalogue
# already knows it) plus whether Wine Words was asked to review it.
#
# Deliberately:
#   * `vintage` is optional — an unexpected package may arrive with a wine that
#     is not in the catalogue yet;
#   * the same vintage may appear in many packages, so there is no uniqueness
#     constraint on (wine_package_id, vintage_id);
#   * `review_requested` is the ONLY signal that blocks package completion.
#     A wine that was not requested for review never blocks anything.
#
# Issue #199 additions: a producer-submitted line may name a wine that is not
# in the catalogue yet (`proposed_wine_name` / `proposed_vintage_year`) and may
# carry its own bottle photos.
#
# "Reviewed" is never a stored flag: it is derived from the linked Review's
# status, so unpublishing a review automatically reopens the work.
class WinePackageItem < ApplicationRecord
  belongs_to :wine_package
  belongs_to :vintage, optional: true
  # Set once a Review has been produced from this item.
  belongs_to :review, optional: true
  # Typed per-line attachments (bottle photos for this wine line).
  has_many :wine_package_attachments,
           class_name: "WinePackageAttachment",
           foreign_key: :wine_package_item_id,
           dependent: :destroy

  validates :quantity,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  # Proposed wine metadata for a producer request (issue #199): when the
  # catalogue does not know the wine yet, the producer names it. A proposed
  # vintage year is a year, not free text.
  validates :proposed_wine_name, length: { maximum: 255 }, allow_blank: true
  validates :proposed_vintage_year,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 1900,
              less_than_or_equal_to: Date.current.year + 2
            },
            allow_nil: true

  # A producer-submitted line must name its wine: either a catalogue vintage
  # or a proposed name. Manual/unexpected editorial packages keep the old
  # tolerance (an unmatchable bottle may still be recorded).
  validate :proposed_wine_named, if: :producer_submitted?

  scope :with_review_requested, -> { where(review_requested: true) }
  scope :reviewed, -> { joins(:review).where(reviews: { status: "published" }) }
  # Requested for review but not yet covered by a published review.
  scope :pending_review, lambda {
    with_review_requested
      .left_joins(:review)
      .where("reviews.id IS NULL OR reviews.status <> ?", "published")
  }
  scope :with_proposed_wine, -> { where.not(proposed_wine_name: nil) }

  # Derived from the review — a draft (or absent) review is not a review.
  def reviewed?
    review&.status == "published"
  end

  # Only items explicitly requested for review are reviewable.
  def reviewable?
    review_requested?
  end

  def pending_review?
    reviewable? && !reviewed?
  end

  def wine
    vintage&.wine
  end

  # Display label; tolerant of a not-yet-matched wine.
  def label
    vintage&.name.presence || proposed_wine_name.presence || "Unmatched wine"
  end

  # True when the line belongs to a producer-requested package.
  def producer_submitted?
    wine_package&.source.in?(%w[producer_request producer_announcement])
  end

  # Automatic completion must be re-evaluated whenever the set of *blocking*
  # lines can change:
  #   * the review link is attached/detached (a review now fulfils this line);
  #   * review_requested is switched off (the last blocker disappears);
  #   * a review_requested line is added — it cannot complete anything, but it
  #     must reopen a package that had already auto-completed;
  #   * the line itself is removed from the package.
  after_save :recheck_package_completion, if: :completion_recheck_needed?
  after_destroy :recheck_package_completion
  # A published review becoming the line's review is a timeline milestone
  # (issue #199 §5). Best-effort: an event failure never breaks the save.
  after_save :record_review_published_event, if: :saved_change_to_review_id?

  private

  def proposed_wine_named
    return if vintage_id.present? || proposed_wine_name.present?

    errors.add(:base, "a catalogue wine or a proposed wine name is required")
  end

  def record_review_published_event
    return if review.nil? || review.status != "published"

    WinePackageEvent.record!(
      wine_package: wine_package,
      event_type: "review_published",
      occurred_at: review.published_at || Time.current,
      metadata: { review_id: review.id, wine_package_item_id: id }
    )
  rescue StandardError => e
    Rails.logger.warn(
      "[WinePackageItem] review_published event not recorded (#{e.class}: #{e.message})"
    )
  end

  def completion_recheck_needed?
    saved_change_to_review_id? ||
      saved_change_to_review_requested? ||
      (previously_new_record? && review_requested?)
  end

  def recheck_package_completion
    package = wine_package
    return if package.nil? || !package.persisted?

    WinePackages::CheckCompletion.call(package)
  end
end
