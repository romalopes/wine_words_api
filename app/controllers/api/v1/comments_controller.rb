# Comment-level endpoints that are NOT nested under a commentable:
#
#   POST   /api/v1/comments/:id/replies   reply to a comment
#   PATCH  /api/v1/comments/:id          edit the body (author or moderator)
#   DELETE /api/v1/comments/:id          soft delete (author or moderator)
#
# The reply's commentable is DERIVED from the parent comment, never taken from
# the request body, so a client cannot attach a reply to a different wine/review/
# article than the one it is replying to. `Comment#parent_must_be_top_level`
# enforces the remaining rule (no reply-to-a-reply, one level only).
class Api::V1::CommentsController < ApplicationController
  include CommentAuthorizable

  before_action :authenticate_user!
  before_action :set_comment, only: [ :update, :destroy, :create_reply ]

  # POST /api/v1/comments/:id/replies
  def create_reply
    return unless authorize_commenter

    parent = @comment
    if parent.reply?
      return render json: { error: "Cannot reply to a reply" },
                    status: :unprocessable_entity
    end

    reply = parent.commentable.comments.build(
      user: current_user,
      parent: parent,
      body: reply_params[:body]
    )

    if reply.save
      render json: CommentSerializer.new(reply, permission, replies: []).as_json,
             status: :created
    else
      validation_error(reply)
    end
  end

  # PATCH /api/v1/comments/:id — body: { comment: { body: "..." } }
  def update
    unless permission.can_edit?(@comment)
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @comment.assign_attributes(update_params)
    return validation_error(@comment) unless @comment.save

    render json: CommentSerializer.new(@comment, permission, replies: []).as_json
  end

  # DELETE /api/v1/comments/:id — soft delete: the thread keeps its shape.
  def destroy
    unless permission.can_delete?(@comment)
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    @comment.soft_delete!
    render json: CommentSerializer.new(@comment, permission, replies: []).as_json
  end

  private

  # The same controller serves two shapes, so the id arrives under two names:
#   PATCH|DELETE /api/v1/comments/:id
#   POST        /api/v1/comments/:comment_id/replies
  def set_comment
    @comment = Comment.includes(:user, :replies).find(params[:comment_id] || params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Comment not found" }, status: :not_found
    nil
  end

  def reply_params
    params.require(:comment).permit(:body)
  end

  # Same shape as reply_params, kept separate so the two writes can diverge
  # without touching each other.
  def update_params
    params.require(:comment).permit(:body)
  end
end