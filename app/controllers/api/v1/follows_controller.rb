# Follow subscriptions: the signed-in user subscribes to a Producer, Wine,
# Review or Article to receive notifications about future activity on it.
#
# One Follow row per user/target (database-enforced unique index); following a
# Producer does NOT create rows for its wines — indirect coverage is computed
# at notification time. Following a draft the user cannot see is rejected.
class Api::V1::FollowsController < ApplicationController
  before_action :authenticate_user!

  # GET /api/v1/follows?page=1&type=Wine
  def index
    follows = current_user.follows.includes(:followable).recent
    follows = follows.for_type(params[:type]) if params[:type].present?

    return if render_paginated(follows) { |items| serialize_follows(items) }

    render json: serialize_follows(follows)
  end

  # POST /api/v1/follows — body: { followable_type: "Wine", followable_id: 50 }
  # Idempotent: the first POST returns 201, a repeat returns 200 with the same
  # row (the unique index backs any race between the lookup and the insert).
  def create
    followable = find_followable
    return if followable.nil?

    existing = Follow.find_by(user: current_user, followable: followable)
    if existing
      return render json: FollowSerializer.new(existing, request.base_url).as_json
    end

    follow = Follow.create!(user: current_user, followable: followable)
    render json: FollowSerializer.new(follow, request.base_url).as_json, status: :created
  rescue ActiveRecord::RecordNotUnique
    # A concurrent duplicate POST won the race; the unique index kept 1 row.
    follow = Follow.find_by!(user: current_user, followable: followable)
    render json: FollowSerializer.new(follow, request.base_url).as_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # DELETE /api/v1/follows/:id — the current user's own Follow only.
  def destroy
    follow = current_user.follows.find_by(id: params[:id])
    return render json: { error: "Follow not found" }, status: :not_found if follow.nil?

    follow.destroy
    render json: { following: false }
  end

  # GET /api/v1/follows/status?followable_type=Wine&followable_id=50
  # The current user's follow state for one target (detail pages).
  def status
    followable = find_followable
    return if followable.nil?

    follow = current_user.follows.find_by(followable: followable)
    render json: {
      followable_type: followable.class.name,
      followable_id: followable.id,
      follow_id: follow&.id,
      following: follow.present?
    }
  end

  # GET /api/v1/follows/statuses?followable_type=Wine&ids[]=1&ids[]=2
  # Batch follow state for list pages — one query instead of N status calls.
  def statuses
    type = params[:followable_type]
    return render json: { error: "Invalid followable type" }, status: :bad_request unless Follow::ALLOWED_TYPES.include?(type)

    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    followed_ids = current_user.follows
                               .where(followable_type: type, followable_id: ids)
                               .pluck(:followable_id)

    render json: { followable_type: type, followed_ids: followed_ids }
  end

  private

  def serialize_follows(follows)
    follows.map { |f| FollowSerializer.new(f, request.base_url).as_json }
  end

  # Resolve the target by slug or id, through the same visibility rules as the
  # likes/comments controllers: drafts are 404 for users who cannot see them
  # (never 403 — existence is not revealed). Unknown types are 404 too.
  def find_followable
    type = params[:followable_type]
    unless Follow::ALLOWED_TYPES.include?(type)
      render json: { error: "Invalid followable type" }, status: :bad_request
      return nil
    end

    scope =
      case type
      when "Review"
        scope = Review.all
        current_user&.wine_manager? ? scope : scope.visible_to(current_user)
      when "Article"
        scope = Article.all
        current_user&.wine_manager? ? scope : scope.visible_to(current_user)
      when "Producer" then Producer.all
      when "Wine" then Wine.all
      end

    followable = scope.find_by(slug: params[:followable_slug]) ||
                 scope.where(id: params[:followable_id]).first
    return followable if followable

    render json: { error: "#{type} not found" }, status: :not_found
    nil
  end
end