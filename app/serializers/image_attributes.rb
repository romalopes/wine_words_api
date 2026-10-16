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
  # Per-process cache: using Rails.cache here would add a Solid Cache database
  # round trip for every image. Entries expire before the storage signature.
  SIGNED_URL_CACHE = ActiveSupport::Cache::MemoryStore.new(size: 16.megabytes)

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
    if blob.service_name == "cloudflare_r2"
      base = ENV["CLOUD_FLARE_R2_PUBLIC_URL"].to_s.strip.delete_suffix("/")
      if base.present?
        uri = URI.parse(base)
        if uri.is_a?(URI::HTTPS) && uri.host.present? && !uri.userinfo && !uri.query && !uri.fragment
          key = blob.key.split("/").map { |part| ERB::Util.url_encode(part) }.join("/")
          return "#{base}/#{key}"
        end
      end
    end
    direct_url(blob)
  rescue URI::InvalidURIError
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

    expiry = ActiveStorage.service_urls_expire_in.to_f
    # Leave at least 20% (normally one minute) for clients to fetch the image.
    ttl = expiry - [60, expiry * 0.2].max
    url = if blob.service_name == "cloudflare_r2" && ttl.positive?
      key = ["image-signed-url-v1", blob.service_name, blob.key,
             blob.filename.to_s, blob.content_type, expiry]
      SIGNED_URL_CACHE.fetch(key, expires_in: ttl) do
        blob.url(disposition: :inline, expires_in: expiry)
      end
    else
      blob.url(disposition: :inline)
    end
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
