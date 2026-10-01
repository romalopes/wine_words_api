# Polymorphic Comment on a Wine, Review or Article, with one level of replies.
#
# The hierarchy is self-referential: `parent_id` NULL is a top-level comment,
# otherwise it points at the comment being replied to. Replies are NOT nested
# deeper — Comment#parent_must_be_top_level enforces it — because the UI is a
# two-level thread and unlimited nesting is a spam/abuse vector.
#
# Deletion is soft (deleted_at): the row survives so replies keep their place in
# the thread and the API can render "[Comment deleted]".
class Comment < ApplicationRecord
  MAX_BODY_LENGTH = 2_000
  DELETED_BODY_PLACEHOLDER = "[Comment deleted]"

  # Types a comment may attach to. Kept as an explicit whitelist (rather than
  # trusting whatever arrives in commentable_type) so a typo or an attempt to
  # attach a comment to, say, a User can never resolve to a model.
  COMMENTABLE_TYPES = %w[Wine Review Article].freeze

  belongs_to :user
  belongs_to :commentable, polymorphic: true

  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies,
           class_name: "Comment",
           foreign_key: :parent_id,
           inverse_of: :parent,
           dependent: :destroy

  validates :commentable_type,
            inclusion: { in: COMMENTABLE_TYPES }
  validates :body,
            presence: true,
            length: { maximum: MAX_BODY_LENGTH }
  validate :parent_must_be_top_level

  scope :visible, -> { where(deleted_at: nil) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :chronological, -> { order(:created_at, :id) }

  def deleted?
    deleted_at.present?
  end

  def reply?
    parent_id.present?
  end

  # What the API should show for this comment. A deleted comment keeps its slot
  # in the thread but never leaks its original text.
  def display_body
    deleted? ? DELETED_BODY_PLACEHOLDER : body
  end

  # Soft delete, cascading to this comment's replies so a removed sub-thread
  # does not keep dangling under a tombstone.
  def soft_delete!
    transaction do
      update!(deleted_at: Time.current)
      replies.visible.update_all(deleted_at: deleted_at, updated_at: deleted_at)
    end
    self
  end

  private

  # One level of replies only. Also rejects a parent belonging to a DIFFERENT
  # commentable, which is the classic polymorphic bypass: without this check a
  # reply created through Review A's endpoint could point at a comment on Wine B.
  def parent_must_be_top_level
    return if parent_id.blank?

    parent_row = parent
    return if parent_row.nil? # orphaned parent_id; belongs_to is optional

    if parent_row.reply?
      errors.add(:parent, "cannot itself be a reply")
    elsif parent_row.commentable_type != commentable_type ||
          parent_row.commentable_id != commentable_id
      errors.add(:parent, "must belong to the same commentable")
    end
  end
end