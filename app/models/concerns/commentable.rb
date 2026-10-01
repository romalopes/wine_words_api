# Shared association for models that can be commented on (Wine, Review,
# Article). Mirrors the Likeable pattern exactly: one `has_many :comments, as:
# :commentable` include makes any future model commentable without touching the
# Comment model.
module Commentable
  extend ActiveSupport::Concern

  included do
    # Destroy (not nullify): the commentable_type whitelist below never yields
    # a NULL commentable, so a nullified comment would be an orphan nobody can
    # reach. Same choice Likeable makes.
    has_many :comments,
             as: :commentable,
             dependent: :destroy
  end

  # Comments that have not been soft deleted.
  def visible_comments
    comments.where(deleted_at: nil)
  end

  # The full thread: every top-level comment, oldest first, with its replies
  # preloaded (one extra query for all replies, never one per row).
  #
  # Soft-deleted comments are INCLUDED here on purpose. They are rendered as
  # "[Comment deleted]" tombstones by CommentSerializer, so a reply keeps the
  # context of what it answered and the thread never silently reflows. Their
  # original text is never sent to the client.
  def comment_thread
    comments
      .where(parent_id: nil)
      .includes(replies: :user)
      .order(:created_at, :id)
  end
end