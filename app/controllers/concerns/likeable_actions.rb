# Shared create/destroy logic for the singular nested `resource :like`
# endpoints (wines / reviews / articles). Keeps the three controllers thin
# and guarantees identical idempotency + race handling everywhere.
module LikeableActions
  extend ActiveSupport::Concern

  # POST /api/v1/<resources>/:id/like — idempotent: repeated calls keep 1 Like.
  def create
    likeable = find_likeable
    return if likeable.nil?

    begin
      likeable.likes.find_or_create_by!(user: current_user)
    rescue ActiveRecord::RecordNotUnique
      # Concurrent duplicate POST won the race; the unique index kept 1 row.
      likeable.likes.find_by(user: current_user)
    end

    likeable.reload
    render json: { liked: true, likes_count: likeable.likes_count }
  end

  # DELETE /api/v1/<resources>/:id/like — idempotent: missing Like is success.
  def destroy
    likeable = find_likeable
    return if likeable.nil?

    likeable.likes.find_by(user: current_user)&.destroy
    likeable.reload
    render json: { liked: false, likes_count: likeable.likes_count }
  end

  private

  # Each including controller defines how its likeable is resolved
  # (slug-aware + visibility-scoped where applicable).
  def find_likeable
    raise NotImplementedError
  end

  def render_likeable_not_found(message)
    render json: { error: message }, status: :not_found
  end
end
