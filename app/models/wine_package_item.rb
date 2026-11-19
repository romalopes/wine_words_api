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
  ITEM_STATUSES = %w[
    pending approved rejected information_requested matched shipped received
  ].freeze

  RECEIPT_CONDITIONS = %w[good damaged missing].freeze

  RESOLUTION_STATUSES = %w[unmatched needs_vintage matched].freeze

  belongs_to :wine_package
  belongs_to :vintage, optional: true
  # Set once a Review has been produced from this item.
  belongs_to :review, optional: true
  # Catalogue linkage for a trade submission (IDENTITY_206 Phase 13): the
  # Editor matches the submitted wine to a catalogue Wine; the Vintage link
  # stays the canonical review anchor.
  belongs_to :catalogue_wine, class_name: "Wine", optional: true
  # Typed per-line attachments (bottle photos for this wine line).
  has_many :wine_package_attachments,
           class_name: "WinePackageAttachment",
           foreign_key: :wine_package_item_id,
           dependent: :destroy

  enum :item_status, ITEM_STATUSES.index_by(&:itself), default: :pending, validate: true

  validates :quantity,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }
  # Ensure vintage and catalogue_wine are consistent when both are set.
  validate :vintage_matches_catalogue_wine
  # A catalogue vintage already identifies its wine, so link the wine too. This
  # keeps the trade/admin "matched" state consistent whether the line was
  # resolved through the editorial form (vintage only) or via match_catalogue.
  before_validation :adopt_catalogue_wine_from_vintage,
                    if: -> { vintage_id.present? && catalogue_wine_id.blank? }
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
  # Trade submissions may declare a non-numeric vintage: NV (non vintage) or
  # MV (multi vintage). Exactly one of {year, label} is meaningful at a time.
  validates :snapshot_vintage_label, inclusion: { in: %w[NV MV] }, allow_nil: true
  # Trade submission snapshot extras (IDENTITY_206 Phase 3).
  validates :snapshot_region, :snapshot_appellation, :snapshot_closure_type,
            length: { maximum: 255 }, allow_blank: true
  validates :snapshot_grape_varieties, length: { maximum: 500 }, allow_blank: true
  validates :snapshot_technical_sheet_url, length: { maximum: 500 }, allow_blank: true
  validates :snapshot_abv,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true
  validates :snapshot_volume_ml, :snapshot_sample_quantity,
            numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :snapshot_trade_price, :snapshot_retail_price,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :condition, inclusion: { in: RECEIPT_CONDITIONS }, allow_blank: true
  validates :item_status, presence: true, inclusion: { in: ITEM_STATUSES }

  # A producer-submitted line must name its wine: either a catalogue vintage
  # or a proposed name. Manual/unexpected editorial packages keep the old
  # tolerance (an unmatchable bottle may still be recorded).
  validate :proposed_wine_named, if: :producer_submitted?
  validate :wine_named, if: -> { wine_package&.trade_submission? }

  scope :with_review_requested, -> { where(review_requested: true) }
  scope :reviewed, -> { joins(:review).where(reviews: { status: "published" }) }
  # Requested for review but not yet covered by a published review.
  scope :pending_review, lambda {
    with_review_requested
      .left_joins(:review)
      .where("reviews.id IS NULL OR reviews.status <> ?", "published")
  }
  scope :with_proposed_wine, -> { where.not(proposed_wine_name: nil) }

  # ---- Trade submission snapshot aliases (IDENTITY_206) --------------------
  # The submission form speaks "snapshot" language; the producer-request flow
  # (issue #199) already named these columns proposed_*. Ruby aliases keep
  # both vocabularies without a destructive rename.
  alias_attribute :snapshot_wine_name, :proposed_wine_name
  alias_attribute :snapshot_vintage, :proposed_vintage_year

  # What the submitter declared as the vintage: "NV"/"MV" when they picked a
  # non-numeric option, otherwise the calendar year. Plain string — no link to
  # the catalogue vintages table.
  def snapshot_vintage_display
    snapshot_vintage_label.presence || snapshot_vintage&.to_s
  end

  # ---- Trade submission receipt helpers (Phase 12/13) ----------------------
  # The item is receipt-eligible when the sample physically arrived in good
  # condition; `condition` and `received_at` are pre-existing columns.
  def receipt_recorded?
    received_at.present?
  end

  def receipt_condition_good?
    condition.blank? || condition == "good"
  end

  def review_eligible?
    item_status == "received" && receipt_condition_good?
  end

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

  # Derived resolution status based on catalogue associations.
  # - unmatched: no catalogue wine selected
  # - needs_vintage: catalogue wine selected but no vintage linked
  # - matched: both catalogue wine and vintage linked
  def resolution_status
    if vintage_id.present? && catalogue_wine_id.present?
      "matched"
    elsif catalogue_wine_id.present?
      "needs_vintage"
    else
      "unmatched"
    end
  end

  # Backward-compatible alias: true when no catalogue association exists.
  def unmatched?
    resolution_status == "unmatched"
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

  # Trade submissions (IDENTITY_206) must always name the wine in the snapshot;
  # catalogue matching happens later (Phase 13), never at submission time.
  # Lines the Wine Words team adds FROM the catalogue are the exception: their
  # identity comes from the linked vintage/catalogue wine, so requiring a
  # snapshot name would make an editorially added bottle impossible to attach.
  def wine_named
    return if proposed_wine_name.present?
    return if vintage_id.present? || catalogue_wine_id.present?

    errors.add(:proposed_wine_name, "is required for a trade submission")
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

  private

  # Ensure vintage belongs to the same wine as catalogue_wine when both are set.
  def vintage_matches_catalogue_wine
    return unless vintage_id.present? && catalogue_wine_id.present?

    unless vintage.wine_id == catalogue_wine_id
      errors.add(:vintage_id, "must belong to the selected catalogue wine")
    end
  end

  # Linking a vintage implicitly links its wine, so consumers that read
  # `catalogue_wine` (trade admin / submitter views) see the same match.
  def adopt_catalogue_wine_from_vintage
    self.catalogue_wine_id = vintage&.wine_id
  end
end
