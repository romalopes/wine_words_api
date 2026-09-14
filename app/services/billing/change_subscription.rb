module Billing
  class ChangeSubscription
    # Preview a plan change (upgrade or downgrade) without charging. Stripe
    # computes any proration; the result is normalized for the UI.
    #
    # @return [Hash] direction, current{}, target{}, due_today{amount_cents,currency},
    #   next_renewal{amount_cents,currency,at}, current_period_end,
    #   provider_subscription_id.
    def self.preview(user:, target_subscription:)
      validate!(user, target_subscription)
      result = Billing.adapter.preview_change(user: user, target_subscription: target_subscription)
      build_preview(user, target_subscription, result)
    end

    # Execute a plan change. An upgrade charges the prorated difference now
    # (Stripe invoices) and is applied locally via webhook; a downgrade only
    # schedules the lower plan effective at the next renewal (no charge/refund).
    #
    # Idempotent per (user, idempotency_key): replaying a key returns the
    # already-created change instead of charging twice.
    def self.confirm(user:, target_subscription:, idempotency_key:)
      validate!(user, target_subscription)

      if idempotency_key.present?
        existing = SubscriptionChange.find_by(user_id: user.id, idempotency_key: idempotency_key)
        if existing
          return { status: existing.status, subscription_change_id: existing.id, already_requested: true }
        end
      end

      change = create_change(user, target_subscription, idempotency_key)
      result = Billing.adapter.change_subscription(
        user: user,
        target_subscription: target_subscription,
        mode: change.change_type.to_sym
      )

      if change.upgrade?
        change.update!(status: :pending)
      else
        change.update!(status: :scheduled, effective_at: result[:effective_at])
      end

      log_change(user, change)

      {
        status: change.status,
        subscription_change_id: change.id,
        effective_at: change.effective_at,
        mode: result[:mode]
      }
    rescue ActiveRecord::RecordNotUnique
      # Two concurrent requests with the same idempotency key: only one won.
      existing = SubscriptionChange.find_by(user_id: user.id, idempotency_key: idempotency_key)
      return { status: existing.status, subscription_change_id: existing.id, already_requested: true } if existing

      raise
    end

    private

    def self.validate!(user, target_subscription)
      raise Billing::Error, "Billing is not configured." unless Billing.configured?

      current_plan = user.subscription
      raise Billing::Error, "You are not on a paid plan to change." if current_plan.nil? || current_plan.free?
      raise Billing::Error, "Target plan is not available." unless target_subscription.active? &&
        target_subscription.visible? && !target_subscription.free?
      raise Billing::Error, "You are already on this plan." if target_subscription.id == current_plan.id

      customer = user.billing_customers.find_by(provider: "stripe")
      raise Billing::Error, "No billing account found. Have you purchased a subscription?" if customer.nil?
    end

    def self.create_change(user, target_subscription, idempotency_key)
      from_plan = user.subscription
      direction = target_subscription.higher_rank_than?(from_plan) ? "upgrade" : "downgrade"
      current_us = user.user_subscriptions.current.first

      user.subscription_changes.create!(
        from_subscription: from_plan,
        to_subscription: target_subscription,
        change_type: direction,
        status: :pending,
        billing_provider: "stripe",
        idempotency_key: idempotency_key.presence,
        provider_subscription_id: current_us&.provider_subscription_id
      )
    end

    def self.build_preview(user, target_subscription, result)
      {
        direction: result[:direction],
        current: plan_payload(user.subscription),
        target: plan_payload(target_subscription),
        due_today: { amount_cents: result[:due_today_cents], currency: result[:currency] },
        next_renewal: {
          amount_cents: result[:next_renewal_cents],
          currency: result[:currency],
          at: result[:next_renewal_at]
        },
        current_period_end: result[:current_period_end],
        provider_subscription_id: result[:provider_subscription_id]
      }
    end

    def self.plan_payload(plan)
      {
        id: plan&.id,
        name: plan&.name,
        slug: plan&.slug,
        rank: plan&.rank,
        yearly_price_cents: plan&.yearly_price_cents
      }
    end

    def self.log_change(user, change)
      LogService.log(
        description: "Subscription #{change.change_type}: " \
                     "#{change.from_subscription&.name} -> #{change.to_subscription&.name}" \
                     "#{change.upgrade? ? " (prorated charge when invoiced)" : " (scheduled at next renewal)"}",
        action: change.upgrade? ? "subscription.upgrade" : "subscription.downgrade_scheduled",
        user: user,
        objects: [user, change.from_subscription, change.to_subscription, change]
      )
    end
  end
end