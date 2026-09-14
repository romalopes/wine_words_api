# Safety net for missed Stripe webhooks. The webhook (customer.subscription.updated
# / invoice.paid) remains the primary sync trigger; this job heals subscriptions
# whose Stripe billing period has advanced but whose local user_subscription is
# still recorded against an old period. It is idempotent (same-period rows are
# skipped) and never raises for the whole batch.
class Billing::ReconcileSubscriptionsJob < ApplicationJob
  queue_as :background

  BATCH_SIZE = 50

  def perform
    stale = UserSubscription.current
            .where(billing_provider: "stripe")
            .where.not(provider_subscription_id: nil)
            .where("current_period_end IS NOT NULL AND current_period_end < ?", Time.current)
            .order(:current_period_end)
            .limit(BATCH_SIZE)

    stale.find_each do |user_sub|
      reconcile(user_sub) unless user_sub.ended_at.present?
    rescue StandardError => e
      Rails.logger.error "[ReconcileSubscriptions] failed subscription #{user_sub&.id}: #{e.class}: #{e.message}"
      sleep(0.2)
    end
  end

  private

  def reconcile(user_sub)
    provider_sub = ::Stripe::Subscription.retrieve(user_sub.provider_subscription_id)
    stripe_end = Time.at(provider_sub.current_period_end) if provider_sub.current_period_end

    # Already in sync? Stripe still shows the same period we recorded locally.
    if provider_sub.status == "active" && stripe_end.present? &&
       user_sub.current_period_end.present? && stripe_end == user_sub.current_period_end
      return
    end

    price_id = provider_sub.items.data[0]&.price&.id
    plan = SubscriptionBillingPrice.active.for_provider(:stripe).find_by(provider_price_id: price_id)&.subscription
    return if plan.nil?

    Billing::Subscription.apply(
      user: user_sub.user,
      subscription: plan,
      billing_provider: "stripe",
      provider_subscription_id: provider_sub.id,
      current_period_start: (Time.at(provider_sub.current_period_start) if provider_sub.current_period_start),
      current_period_end: stripe_end,
      allow_downgrade: true
    )

    LogService.log(
      description: "Reconciled subscription to #{plan.name} (period ends #{stripe_end}) for #{user_sub.user&.user_name || user_sub.user&.email}",
      action: "subscription.reconciled",
      user: user_sub.user,
      path: "background/job/reconcile_subscriptions",
      objects: [user_sub.user, plan]
    )
  end
end