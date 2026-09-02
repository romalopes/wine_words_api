class Api::V1::SubscriptionsController < ApplicationController
  # Public read of visible+active plans; Super Users also see hidden/inactive ones.
  skip_before_action :authenticate_user!, only: :index

  before_action :ensure_super_user!, only: [:show, :create, :update, :destroy]

  # GET /api/v1/subscriptions
  def index
    subs = current_user&.super_admin? ? Subscription.all : Subscription.active.visible
    render json: subs.by_position.map { |s| subscription_json(s) }
  end

  # GET /api/v1/subscriptions/:id
  def show
    sub = Subscription.find(params[:id])
    render json: subscription_json(sub)
  end

  # POST /api/v1/subscriptions
  def create
    sub = Subscription.new(subscription_params)
    if sub.save
      render json: subscription_json(sub), status: :created
    else
      render json: { errors: sub.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/subscriptions/:id
  def update
    sub = Subscription.find(params[:id])
    if sub.update(subscription_params)
      render json: subscription_json(sub)
    else
      render json: { errors: sub.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/subscriptions/:id
  # Refuses to destroy plans that have users or history; use active:false / visible:false instead.
  def destroy
    sub = Subscription.find(params[:id])
    if sub.destroy
      head :no_content
    else
      render json: { errors: sub.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def ensure_super_user!
    return if current_user&.super_admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def subscription_params
    params.require(:subscription).permit(
      :name, :slug, :description, :popular, :visible, :active,
      :is_default, :position, :monthly_price_cents, :yearly_price_cents, :currency,
      subscription_subscription_features_attributes: [:id, :subscription_feature_id, :position, :_destroy]
    )
  end

  def subscription_json(sub)
    {
      id: sub.id,
      name: sub.name,
      slug: sub.slug,
      description: sub.description,
      popular: sub.popular,
      visible: sub.visible,
      active: sub.active,
      is_default: sub.is_default,
      position: sub.position,
      monthly_price_cents: sub.monthly_price_cents,
      yearly_price_cents: sub.yearly_price_cents,
      currency: sub.currency,
      features: sub.subscription_subscription_features.order(:position).map do |ssf|
        { id: ssf.subscription_feature_id, name: ssf.subscription_feature.name, position: ssf.position }
      end
    }
  end
end