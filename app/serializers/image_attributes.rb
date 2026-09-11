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
    record.images.ordered.filter_map do |image|
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
    record.images.ordered.filter_map do |image|
      blob_url(image.file.blob) if image.file.attached?
    end
  end

  def image_ids(record)
    record.images.ordered.map(&:id)
  end

  def primary_image(record)
    images = image_details(record)
    primary = images.find { |img| img[:primary] }
    (primary || images.first)&.fetch(:url)
  end

  def blob_url(blob)
    Rails.application.routes.url_helpers.rails_blob_url(
      blob,
      host: @base_url || "localhost:3000"
    )
  end
end