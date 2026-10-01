# Threaded JSON for a Comment, used by the commentable endpoints
# (GET/POST /wines|reviews|articles/:id/comments) and by the replies endpoint.
#
# The hierarchy is assembled HERE so the React app never has to reconstruct it:
# a top-level comment carries its own `replies` array, each reply carrying an
# empty one (replies are never nested deeper — see Comment).
#
# `editable` / `deletable` are resolved through Comments::Permission once, at
# serialization time, so the client renders exactly the actions the API would
# actually allow.
class CommentSerializer
  def initialize(comment, permission, replies: nil)
    @comment = comment
    @permission = permission
    @replies = replies
  end

  def as_json
    {
      id: @comment.id,
      body: @comment.display_body,
      deleted: @comment.deleted?,
      parent_id: @comment.parent_id,
      commentable_type: @comment.commentable_type,
      commentable_id: @comment.commentable_id,
      author: author,
      created_at: @comment.created_at&.iso8601,
      updated_at: @comment.updated_at&.iso8601,
      edited: @comment.updated_at.present? && @comment.updated_at > @comment.created_at,
      editable: @permission.can_edit?(@comment),
      deletable: @permission.can_delete?(@comment),
      replies: replies
    }
  end

  private

  def author
    user = @comment.user
    {
      id: user&.id,
      name: user&.user_name || user&.email || "Unknown"
    }
  end

  # Replies are passed in already loaded (includes(replies: :user) on the
  # thread query) and are ordered oldest-first. Deleted replies are kept in the
  # payload as tombstones so the thread reads in order.
  def replies
    (@replies || @comment.replies.order(:created_at, :id)).map do |reply|
      self.class.new(reply, @permission, replies: []).as_json
    end
  end
end