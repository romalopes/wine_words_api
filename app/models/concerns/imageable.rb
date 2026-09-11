# Shared association for models that carry multiple application-level images
# (Wine, Article, Review, Producer). Provides a polymorphic `images` collection
# ordered by position, mirroring the plan's "has_many :images, as: :imageable".
module Imageable
  extend ActiveSupport::Concern

  included do
    has_many :images,
             -> { ordered },
             as: :imageable,
             class_name: "Image",
             dependent: :destroy
  end

  # URLs of every attached file, ordered (position asc). Falls back to an
  # empty array when there are no images.
  def image_urls(base_url = nil)
    images.ordered.filter_map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(
        image.file.blob,
        host: base_url || "localhost:3000"
      ) if image.file.attached?
    end
  end
end