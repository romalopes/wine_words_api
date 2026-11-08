class Api::V1::PushSubscriptionsController < ApplicationController
  def vapid_public_key
    render json: { public_key: ENV["VAPID_PUBLIC_KEY"] }
  end

  def index
    render json: current_user.push_subscriptions.order(created_at: :desc).map { |row| serialize(row) }
  end

  def create
    endpoint = subscription_params.fetch(:endpoint)
    subscription = PushSubscription.find_or_initialize_by(endpoint: endpoint)
    if subscription.persisted? && subscription.user_id != current_user.id
      return render json: { error: "Subscription already registered" }, status: :conflict
    end

    subscription.assign_attributes(
      user: current_user,
      p256dh: subscription_params.fetch(:p256dh),
      auth: subscription_params.fetch(:auth),
      user_agent: request.user_agent,
      last_used_at: Time.current
    )
    subscription.save!
    NotificationPreference.for(current_user).update!(push_enabled: true)
    render json: serialize(subscription), status: subscription.previously_new_record? ? :created : :ok
  end

  def destroy
    subscription = current_user.push_subscriptions.find(params[:id])
    subscription.destroy!
    if current_user.push_subscriptions.reload.none?
      NotificationPreference.for(current_user).update!(push_enabled: false)
    end
    head :no_content
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Push subscription not found" }, status: :not_found
  end

  private

  def subscription_params
    params.require(:push_subscription).permit(:endpoint, :p256dh, :auth)
  end

  def serialize(subscription)
    {
      id: subscription.id,
      endpoint: subscription.endpoint,
      user_agent: subscription.user_agent,
      last_used_at: subscription.last_used_at&.iso8601
    }
  end
end
