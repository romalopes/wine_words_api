module Web
  class SubscribeController < BaseController
    before_action :require_sign_in!, only: [ :create ]

    # Subscription landing page. Reuses the existing billing models/services
    # (Subscription + Billing::Checkout) that power the API billing endpoint,
    # so the web and API share one source of truth for purchasing.
    def index
      @subscriptions = Subscription.visible.active.paid.by_position
      @current_subscription = current_user&.subscription
    end

    # POST /subscribe — starts checkout for a chosen subscription.
    def create
      subscription = Subscription.find_by(id: params[:subscription_id])
      unless subscription&.active? && subscription.visible? && !subscription.free?
        redirect_to subscribe_path, alert: "This subscription is not available for purchase."
        return
      end

      result = Billing::Checkout.create(user: current_user, subscription: subscription)
      redirect_to result.fetch(:url), allow_other_host: true
    rescue ActiveRecord::RecordNotFound, Billing::Error => e
      redirect_to subscribe_path, alert: e.respond_to?(:message) ? e.message : "Subscription not found."
    end

    private

    def require_sign_in!
      return if user_signed_in?

      redirect_to login_path, alert: "Please sign in to subscribe."
    end
  end
end
