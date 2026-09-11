# Application-level image. Polymorphically belongs to any model that can carry
# multiple images (currently Wine, Article, Review, Producer) and owns its file
# via a single Active Storage attachment (has_one_attached :file).
#
# Provides persistent ordering (position) and a single-primary guarantee at the
# application level. Serializers expose this rich contract to the React app;
# the Rails API re-uses the same rules.
class Image < ApplicationRecord
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  MAX_BYTE_SIZE = 10.megabytes

  belongs_to :imageable, polymorphic: true, touch: true
  has_one_attached :file

  scope :ordered, -> { order(:position, :id) }

  before_validation :assign_position, on: :create
  validate :file_content_type_and_size, if: -> { file.attached? }
  validate :ensure_single_primary, if: -> { primary? }

  # Promote this image to the primary image for its imageable, demoting any
  # other primary first. Runs inside a transaction so the invariant holds even
  # under concurrent requests.
  def make_primary!
    transaction do
      imageable&.images&.where.not(id: id)&.update_all(primary: false)
      update!(primary: true)
    end
  end

  # Applies a new order to the imageable's images from a list of ids, appending
  # any images omitted from the list after them (preserving their relative order).
  def self.reorder!(imageable, ordered_ids)
    ordered = Array(ordered_ids).flatten.map(&:to_i).uniq
    transaction do
      images = imageable.images.to_a
      by_id  = images.to_h { |img| [img.id, img] }

      ordered.each_with_index do |id, idx|
        by_id[id]&.update!(position: idx + 1)
      end

      next_position = ordered.size + 1
      images.each do |img|
        next if ordered.include?(img.id)

        img.update!(position: next_position)
        next_position += 1
      end
    end
  end

  private

  # By default new images append after the current highest position.
  def assign_position
    return if position.to_i.positive?

    self.position = (imageable&.images&.maximum(:position) || 0) + 1
  end

  def file_content_type_and_size
    return unless file.attached?

    blob = file.attachment&.blob
    unless ALLOWED_CONTENT_TYPES.include?(blob&.content_type)
      errors.add(:file, "must be a JPG, PNG, WEBP or GIF image")
    end
    return if blob&.byte_size&.nil? || blob.byte_size <= MAX_BYTE_SIZE

    errors.add(:file, "must be smaller than #{MAX_BYTE_SIZE / 1.megabyte} MB")
  end

  def ensure_single_primary
    return if imageable.nil?

    if imageable.images.where.not(id: id).where(primary: true).exists?
      errors.add(:primary, "There can only be one primary image")
    end
  end
end