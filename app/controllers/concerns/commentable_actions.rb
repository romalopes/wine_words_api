# Shared index/create logic for the nested comments endpoints
# (wines / reviews / articles). Mirrors LikeableActions: the three controllers
# stay thin and identical behaviour is guaranteed everywhere.
#
# Reads follow the API-wide authentication rule (ApplicationController requires
# a Bearer JWT on every Api::V1 action), so `index` needs no extra gate; the
# explicit `before_action :authenticate_user!, only: [ :create ]` on each
# including controller documents the intent and mirrors the likeable controllers.
#
# Writes additionally require a role allowed to comment (see Comments::Permission).
module CommentableActions
  extend ActiveSupport::Concern
  include CommentAuthorizable

  # GET /api/v1/<resources>/:id/comments
  def index
    commentable = find_commentable
    return if commentable.nil?

    # Loaded once: `comment_count` is derived from the thread rather than a
    # second COUNT query, and the scope is already in memory.
    thread = commentable.comment_thread.to_a
    render json: {
      comments: serialize_thread(thread),
      comments_count: thread.size
    }
  end

  # POST /api/v1/<resources>/:id/comments — body: { comment: { body: "..." } }
  def create
    return unless authorize_commenter

    commentable = find_commentable
    return if commentable.nil?

    comment = commentable.comments.build(
      user: current_user,
      body: comment_params[:body]
    )

    if comment.save
      render json: CommentSerializer.new(comment, permission, replies: []).as_json,
             status: :created
    else
      validation_error(comment)
    end
  end

  private

  # Each including controller defines how its commentable is resolved
  # (slug-aware + visibility-scoped where applicable) and returns nil after
  # rendering a 404, exactly like the likeable controllers.
  def find_commentable
    raise NotImplementedError
  end

  def comment_params
    params.require(:comment).permit(:body)
  end

  def serialize_thread(scope)
    scope.map { |comment| CommentSerializer.new(comment, permission).as_json }
  end

  def render_commentable_not_found(message)
    render json: { error: message }, status: :not_found
  end
end