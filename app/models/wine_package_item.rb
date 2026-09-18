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
# "Reviewed" is never a stored flag: it is derived from the linked Review's
# status, so unpublishing a review automatically reopens the work.
class WinePackageItem < ApplicationRecord
  belongs_to :wine_package
  belongs_to :vintage, optional: true
  # Set once a Review has been produced from this item.
  belongs_to :review, optional: true

  validates :quantity,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  scope :with_review_requested, -> { where(review_requested: true) }
  scope :reviewed, -> { joins(:review).where(reviews: { status: "published" }) }
  # Requested for review but not yet covered by a published review.
  scope :pending_review, lambda {
    with_review_requested
      .left_joins(:review)
      .where("reviews.id IS NULL OR reviews.status <> ?", "published")
  }

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
    vintage&.name.presence || "Unmatched wine"
  end

  # Automatic completion must be re-evaluated whenever it can change:
  #   * the review link is attached/detached (a review now fulfils this line);
  #   * the item itself is removed from the package.
  # Adding a review_requested item can only add pending work, never complete a
  # package, so a plain create needs no re-check.
  after_save :recheck_package_completion, if: :saved_change_to_review_id?
  after_destroy :recheck_package_completion

  private

  def recheck_package_completion
    package = wine_package
    return if package.nil? || !package.persisted?

    WinePackages::CheckCompletion.call(package)
  end
end
