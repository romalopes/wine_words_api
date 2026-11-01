# A WinePackageAttachment is one typed file a producer (or editor) uploads
# against a package or a single package line: bottle photos, parcel photos,
# postal receipts, shipping labels, technical sheets, tasting notes.
#
# Design notes (issue #199):
#   * the bytes live in Active Storage (Cloudflare R2 in production) and are
#     always fetched through short-lived signed URLs — never a public,
#     permanent object URL;
#   * `visibility` is the confidentiality boundary: `shared` files are visible
#     to the producer members of the package's producer, `internal` files are
#     editorial-only and never leave the editorial surface;
#   * an attachment may optionally belong to a single WinePackageItem (e.g. a
#     bottle photo for one wine line).
class WinePackageAttachment < ApplicationRecord
  ATTACHMENT_TYPES = %w[
    bottle_photo parcel_photo postal_receipt shipping_label technical_sheet
    tasting_notes other
  ].freeze
  VISIBILITIES = %w[shared internal].freeze

  # Generous but bounded: photos and PDFs up to 15 MB.
  MAX_FILE_SIZE = 15.megabytes
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/webp image/heic application/pdf
  ].freeze

  belongs_to :wine_package
  belongs_to :wine_package_item, optional: true
  belongs_to :uploaded_by, class_name: "User", optional: false

  has_one_attached :file

  validates :attachment_type, inclusion: { in: ATTACHMENT_TYPES }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :caption, length: { maximum: 255 }
  validate :file_presence, on: :create
  validate :file_content_type, if: -> { file.attached? }
  validate :file_size, if: -> { file.attached? }

  scope :shared, -> { where(visibility: "shared") }
  scope :internal, -> { where(visibility: "internal") }
  scope :of_type, ->(type) { where(attachment_type: type) }
  scope :chronological, -> { order(created_at: :asc, id: :asc) }

  # Files visible to the given viewer: editors see everything, producer
  # members (and everyone else) only see the shared ones.
  scope :visible_to, lambda { |editorial|
    editorial ? all : shared
  }

  def shared? = visibility == "shared"

  def internal? = visibility == "internal"

  private

  def file_presence
    errors.add(:file, "must be attached") unless file.attached?
  end

  def file_content_type
    return if ALLOWED_CONTENT_TYPES.include?(file.content_type)

    errors.add(:file, "content type #{file.content_type.inspect} is not allowed " \
                      "(allowed: #{ALLOWED_CONTENT_TYPES.join(', ')})")
  end

  def file_size
    return if file.blob.byte_size <= MAX_FILE_SIZE

    errors.add(:file, "is larger than the #{MAX_FILE_SIZE / 1.megabyte} MB limit")
  end
end
