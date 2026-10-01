# Controller-side authorization for comments: the Comments::Permission lookup and
# the 403 response. Shared by the commentable endpoints (CommentableActions) and
# by Api::V1::CommentsController so both speak the same language.
module CommentAuthorizable
  extend ActiveSupport::Concern

  private

  def permission
    @permission ||= Comments::Permission.new(current_user)
  end

  # Gate for every write. Returns false after rendering 403 when the account may
  # not comment (Guest), so callers can `return unless authorize_commenter`.
  def authorize_commenter
    return true if permission.can_comment?

    render json: { error: "Your account cannot comment" }, status: :forbidden
    false
  end
end