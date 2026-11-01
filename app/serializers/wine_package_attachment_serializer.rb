# One typed attachment of a WinePackage (or of a single package line):
# bottle photos, parcel photos, postal receipts, shipping labels, technical
# sheets and tasting notes (issue #199 §3).
#
# The URL is a short-lived signed storage URL (or the R2 public URL when the
# blob is stored on the public R2 service), generated through the same
# ImageAttributes contract used across the API — the raw storage key is never
# exposed and access control happens at the API layer, not the URL layer.
class WinePackageAttachmentSerializer
  include ImageAttributes

  def initialize(attachment, base_url = nil)
    @attachment = attachment
    @base_url = base_url
  end

  def as_json
    {
      id: @attachment.id,
      wine_package_id: @attachment.wine_package_id,
      wine_package_item_id: @attachment.wine_package_item_id,
      uploaded_by_id: @attachment.uploaded_by_id,
      attachment_type: @attachment.attachment_type,
      visibility: @attachment.visibility,
      caption: @attachment.caption,
      filename: @attachment.file&.filename&.to_s,
      content_type: @attachment.file&.content_type,
      byte_size: @attachment.file&.byte_size,
      url: file_url,
      created_at: @attachment.created_at&.iso8601,
      updated_at: @attachment.updated_at&.iso8601
    }
  end

  private

  def file_url
    blob_url(@attachment.file.blob) if @attachment.file&.attached?
  end
end
