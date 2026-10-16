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
  #
  # Uses direct pre-signed storage URLs (see ImageAttributes#direct_url) so
  # the browser skips the /rails/active_storage/blobs/redirect round trip.
  def image_urls(base_url = nil)
    images.ordered.filter_map do |image|
      next unless image.file.attached?

      safe_direct_url(image.file.blob, base_url)
    end
  end

  private

  def safe_direct_url(blob, base_url)
    previous = ActiveStorage::Current.url_options
    ActiveStorage::Current.url_options ||= begin
      uri = URI.parse(base_url || "http://localhost:3000")
      options = { host: uri.host || "localhost", protocol: "#{uri.scheme}://" }
      options[:port] = uri.port unless uri.default_port == uri.port
      options
    end

    url = blob.url(disposition: :inline)
    # Absolutize relative (Disk service) URLs against the request base URL.
    url.start_with?("http") ? url : "#{base_url || 'localhost:3000'}#{url}"
  rescue StandardError => e
    Rails.logger.warn(
      "[Imageable] direct storage URL failed (#{e.class}: #{e.message}); " \
      "falling back to redirect URL"
    )
    Rails.application.routes.url_helpers.rails_blob_url(
      blob,
      host: base_url || "localhost:3000"
    )
  ensure
    ActiveStorage::Current.url_options = previous
  end
end
