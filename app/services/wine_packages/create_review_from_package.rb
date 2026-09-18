module WinePackages
  # Starts the standard review workflow from a package item.
  #
  # The Review is created through the ordinary path — same validations, slug
  # generation, score rules and image support as any other review — and is then
  # attached to the item. The link lives on wine_package_items.review_id (one
  # link, one truth), and completion is re-checked afterwards.
  #
  # Order matters: the review is saved BEFORE the link is written, so the
  # Review completion hook cannot fire against a half-built association.
  # Linking the item then triggers the item-side completion check, which is what
  # completes the package when a published review is created directly.
  #
  # Raises WinePackages::Error when the item cannot produce a review.
  class CreateReviewFromPackage
    def self.call(item, user:, attributes: {})
      new(item, user: user, attributes: attributes).call
    end

    def initialize(item, user:, attributes: {})
      @item = item
      @user = user
      @attributes = (attributes || {}).to_h.symbolize_keys
    end

    def call
      raise WinePackages::Error, "This item is not marked for review." unless item.reviewable?
      raise WinePackages::Error, "This item already has a review." if item.review.present?
      raise WinePackages::Error, "This item is not linked to a wine yet." if item.vintage.nil?
      raise WinePackages::Error, "A review needs a reviewer." if user.nil?

      review = Review.new(attributes.merge(vintage: item.vintage, user: user))
      review.save!
      item.update!(review: review)

      review
    end

    private

    attr_reader :item, :user, :attributes
  end
end
