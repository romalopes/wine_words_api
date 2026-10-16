# Shared image contract for API serializers. Models include the Imageable
# concern, so `record.images` is an ordered collection of Image records.
#
# Exposes:
#   * images        -> array of URL strings, position-ordered (backward compat)
#   * image_ids     -> array of Image ids, position-ordered (backward compat;
#                      note: these are now Image ids, not Active Storage ids)
#   * image_details -> rich objects: { id, url, filename, content_type,
#                                      position, primary }
#   * primary_image -> the primary (else first) image URL, or nil
module ImageAttributes
  private

  def image_details(record)
    ordered_images(record).filter_map do |image|
      file = image.file
      next unless file.attached?

      {
        id: image.id,
        url: blob_url(file.blob),
        filename: file.filename.to_s,
        content_type: file.content_type,
        position: image.position,
        primary: image.primary?
      }
    end
  end

  def image_urls(record)
    ordered_images(record).filter_map do |image|
      blob_url(image.file.blob) if image.file.attached?
    end
  end

  def image_ids(record)
    ordered_images(record).map(&:id)
  end

  # `record.images.ordered` is not free on a listing: chaining a scope onto a
  # `CollectionProxy` runs a fresh statement even when `images` was preloaded,
  # which is one query per record. When the association *is* loaded, sorting
  # the rows in Ruby gives the same `position, id` order without the round trip.
  def ordered_images(record)
    images = record.images
    return images.ordered unless images.loaded?

    images.sort_by { |image| [image.position.to_i, image.id.to_i] }
  end

  def primary_image(record)
    images = image_details(record)
    primary = images.find { |img| img[:primary] }
    (primary || images.first)&.fetch(:url)
  end

  def blob_url(blob)
    direct_url(blob)
  end

  # Direct, pre-signed storage URL (Cloudflare R2 / S3). The browser fetches
  # the bytes straight from the bucket instead of bouncing through
  # /rails/active_storage/blobs/redirect — which cost one Rails request per
  # image per page view (blob lookup + 302). Presigned URLs expire after
  # config.active_storage.service_urls_expire_in (default: 5 minutes).
  # Falls back to the redirect URL whenever the service cannot pre-sign so
  # responses never fail because of URL generation.
  def direct_url(blob)
    # Disk (dev/test) refuses to sign URLs without ActiveStorage::Current.url_options.
    # When the request middleware hasn't set them, derive them from the request
    # base URL. S3-compatible services (R2) ignore these and presign from the
    # endpoint instead.
    previous = ActiveStorage::Current.url_options
    ActiveStorage::Current.url_options ||= storage_url_options

    url = blob.url(disposition: :inline)
    # S3-compatible services return absolute presigned URLs; Disk (dev/test)
    # returns a signed path — absolutize it against the request base URL so
    # browser-facing payloads stay absolute regardless of the service.
    url.start_with?("http") ? url : "#{@base_url || 'localhost:3000'}#{url}"
  rescue StandardError => e
    Rails.logger.warn(
      "[ImageAttributes] direct storage URL failed (#{e.class}: #{e.message}); " \
      "falling back to redirect URL"
    )
    Rails.application.routes.url_helpers.rails_blob_url(
      blob,
      host: @base_url || "localhost:3000"
    )
  ensure
    ActiveStorage::Current.url_options = previous
  end

  def storage_url_options
    uri = URI.parse(@base_url || "http://localhost:3000")
    options = { host: uri.host || "localhost", protocol: "#{uri.scheme}://" }
    options[:port] = uri.port unless uri.default_port == uri.port
    options
  end
end
