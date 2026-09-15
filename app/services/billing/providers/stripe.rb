# Stripe billing provider adapter.
#
# All Stripe-specific knowledge lives here: product/price/customer/checkout/
# portal session creation and the mapping of Stripe subscription statuses to
# the application's status vocabulary. Nothing outside this file references
# the Stripe gem or Stripe ids.
module Billing
  module Providers
    class Stripe < Base
      def provider_key
        :stripe
      end

      def self.configured?
        ENV["STRIPE_SECRET_KEY"].present?
      end

      def ensure_customer(user)
        customer = ::Stripe::Customer.create(
          email: user.email,
          name: user.user_name,
          metadata: { user_id: user.id }
        )
        { id: customer.id }
      end

      def create_checkout_session(user:, subscription:, billing_price:, success_url:, cancel_url:)
        # Reuse the app's Stripe customer so webhook events (which carry the
        # customer id) map back to the user. Passing only customer_email would
        # make Stripe create a NEW customer on every checkout.
        customer = Billing::Customer.ensure!(user)

        session = ::Stripe::Checkout::Session.create(
          mode: "subscription",
          customer: customer.provider_customer_id,
          line_items: [{
            price: billing_price.provider_price_id,
            quantity: 1
          }],
          success_url: success_url,
          cancel_url: cancel_url,
          metadata: {
            subscription_id: subscription.id,
            billing_price_id: billing_price.id
          }
        )
        { url: session.url, session_id: session.id }
      end

      def create_portal_session(user:, return_url:)
        customer = Billing::Customer.ensure!(user)
        raise Billing::Error, "No billing customer to open a portal." if customer.nil?

        session = ::Stripe::BillingPortal::Session.create(
          customer: customer.provider_customer_id,
          return_url: return_url
        )
        { url: session.url }
      end

      # Preview a subscription plan change. Delegates the proration arithmetic to
      # Stripe (Stripe::Invoice.create_preview — the replacement for the retired
      # Invoice.upcoming endpoint) — never reproduced in Rails.
      #
      # @return [Hash] direction (upgrade|downgrade|same), due_today_cents,
      #   currency, next_renewal_cents, next_renewal_at,
      #   provider_subscription_id, current_period_end.
      def preview_change(user:, target_subscription:)
        provider_sub = current_subscription(user)
        raise Billing::Error, "No active Stripe subscription to change." if provider_sub.nil?

        item = provider_sub.items.data[0]
        period = item_period(provider_sub)
        target_price = target_subscription.billing_price_for("stripe")
        if target_price.nil? || target_price.provider_price_id.blank?
          raise Billing::Error, "This subscription has no Stripe price to change to."
        end

        direction =
          if target_subscription.higher_rank_than?(user.subscription)
            "upgrade"
          elsif target_subscription.lower_rank_than?(user.subscription)
            "downgrade"
          else
            "same"
          end

        # stripe >= 15 moved the "upcoming invoice" preview to the Create
        # Preview endpoint, with the subscription overrides under
        # subscription_details (subscription_items / subscription_proration_date
        # no longer exist).
        upcoming = ::Stripe::Invoice.create_preview(
          customer: provider_sub.customer,
          subscription: provider_sub.id,
          subscription_details: {
            items: [
              { id: item.id, price: target_price.provider_price_id, quantity: item.quantity || 1 }
            ],
            proration_date: Time.current.to_i
          },
          # Expand the parent so we can inspect parent.subscription_item_details.proration.
          # Stripe documents this as the way to isolate prorations (see
          # https://docs.stripe.com/api/invoices/create_preview). Note: the line-level
          # subscription_item_details and invoice_item_details are NOT expandable on
          # this endpoint, so we rely on the parent chain.
          expand: ["lines.data.parent"]
        )

        # Amount due today = the prorations only.
        #
        # `preview_mode` defaults to "next", so the invoice we get back is the
        # *upcoming* one and its `amount_due` bundles the proration together with
        # the next renewal charge (e.g. Trade -> Distributor is
        # 160 proration + 400 renewal = 560). Stripe's documented way to isolate
        # the proration is to keep only the line items flagged
        # `parent.subscription_item_details.proration`; stripe >= 19 dropped the
        # old top-level line-item `proration` flag, so reading it returned nil for
        # every line and this silently summed to 0.
        due_today = upcoming.lines.data
                           .select { |line| proration_line?(line) }
                           .sum(&:amount).to_i

        # A downgrade is scheduled for the next renewal and collects nothing now
        # (Stripe shows a credit that is applied to the next invoice).
        due_today = 0 if direction == "downgrade"

        {
          direction: direction,
          currency: upcoming.currency,
          due_today_cents: due_today,
          next_renewal_cents: target_price.amount_cents.to_i,
          next_renewal_at: period[:end],
          current_period_end: period[:end],
          provider_subscription_id: provider_sub.id
        }
      rescue ::Stripe::StripeError => e
        raise Billing::Error, "Stripe could not preview this change: #{e.message}"
      end

      # Apply a subscription plan change.
      #
      # upgrade  -> Stripe::Subscription.update with `always_invoice`, so Stripe
      #             immediately invoices the prorated difference. The billing
      #             anchor is kept (only the price/item changes). A charge that
      #             needs authentication is returned as an open invoice URL for
      #             the customer to complete.
      # downgrade-> Keep the current plan until the next renewal using a
      #             Stripe SubscriptionSchedule (no refund, no charge now).
      #
      # @return [Hash] mode, provider_subscription_id, effective_at (downgrade),
      #   provider_invoice_id, hosted_invoice_url (upgrade, when payment is still
      #   outstanding).
      def change_subscription(user:, target_subscription:, mode:)
        provider_sub = current_subscription(user)
        raise Billing::Error, "No active Stripe subscription to change." if provider_sub.nil?

        item = provider_sub.items.data[0]
        period = item_period(provider_sub)
        target_price = target_subscription.billing_price_for("stripe")
        if target_price.nil? || target_price.provider_price_id.blank?
          raise Billing::Error, "This subscription has no Stripe price to change to."
        end

        current_price_id = item.price.id
        quantity = item.quantity || 1

        if mode == :upgrade
          # `always_invoice` finalizes an invoice for the proration right away,
          # which is what actually bills the difference today. `create_prorations`
          # (the default) only invoices immediately when the subscription's
          # billing cycle anchor is reset — we deliberately keep the anchor, so
          # the charge would otherwise be deferred into next year's renewal.
          #
          # `allow_incomplete` lets the change stand when the charge needs
          # authentication (3DS/SCA): the invoice stays `open` and we hand the
          # customer its hosted URL to pay.
          subscription = ::Stripe::Subscription.update(
            provider_sub.id,
            items: [{ id: item.id, price: target_price.provider_price_id }],
            proration_behavior: "always_invoice",
            # Match the clock used by preview_change so the customer is billed
            # exactly the proration they were shown.
            proration_date: Time.current.to_i,
            payment_behavior: "allow_incomplete",
            expand: ["latest_invoice"],
            metadata: {
              from_subscription_id: user.subscription_id,
              to_subscription_id: target_subscription.id,
              change_type: "upgrade"
            }
          )

          invoice = latest_invoice_for(subscription)
          {
            mode: "upgrade",
            provider_subscription_id: provider_sub.id,
            provider_invoice_id: invoice&.id,
            # Only surfaced while the charge is outstanding; a paid invoice
            # needs no customer action.
            hosted_invoice_url: (invoice.hosted_invoice_url if invoice&.status == "open")
          }
        else
          # Phase 1 = current price until the end of the current billing period
          # (end_date is the billing anchor), phase 2 = the lower price
          # indefinitely from the next renewal. (stripe >= 15 removed the
          # phase `iterations` param in favour of end_date / duration.)
          #
          # If the subscription already has a schedule (from a previous upgrade
          # that went through a schedule, or a prior downgrade), update it
          # instead of creating a new one — Stripe rejects duplicate schedules.
          #
          # `provider_sub.schedule` may be a String (schedule ID when not expanded)
          # or a full Stripe::SubscriptionSchedule object (when expanded). Handle
          # both cases.
          existing_schedule_id = if provider_sub.respond_to?(:schedule) && provider_sub.schedule
            provider_sub.schedule.is_a?(String) ? provider_sub.schedule : provider_sub.schedule.id
          end

          if existing_schedule_id
            schedule_to_use_id = existing_schedule_id
            # Reuse the existing current phase's start_date — Stripe forbids
            # modifying the start date of the current phase, but the update API
            # requires a start_date on the first phase to anchor end dates.
            existing_schedule = ::Stripe::SubscriptionSchedule.retrieve(existing_schedule_id)
            existing_start =
              (existing_schedule.current_phase&.start_date if existing_schedule.respond_to?(:current_phase)) ||
              existing_schedule.phases&.data&.first&.start_date
          else
            new_schedule = ::Stripe::SubscriptionSchedule.create(
              from_subscription: provider_sub.id
            )
            schedule_to_use_id = new_schedule.id
            existing_start = nil
          end

          # "now" is only valid for a freshly created schedule; an existing
          # schedule must keep its current phase's original start date.
          first_phase = {
            items: [{ price: current_price_id, quantity: quantity }],
            end_date: period[:end]&.to_i
          }
          first_phase[:start_date] = existing_start || "now"

          ::Stripe::SubscriptionSchedule.update(
            schedule_to_use_id,
            phases: [
              first_phase,
              { items: [{ price: target_price.provider_price_id, quantity: 1 }] }
            ]
          )
          {
            mode: "downgrade",
            provider_subscription_id: provider_sub.id,
            effective_at: period[:end]
          }
        end
      rescue ::Stripe::StripeError => e
        raise Billing::Error, "Stripe could not apply this change: #{e.message}"
      end

      # Build { user:, subscription:, plan:, status:, provider_subscription_id:,
      #       billing_price: } from a Stripe subscription object payload.
      def build_subscription_from_event(payload)
        customer_id = payload.dig("customer")
        sub_id = payload.dig("id")

        billing_customer = BillingCustomer.find_by(provider: "stripe", provider_customer_id: customer_id)
        return nil if billing_customer.blank?

        plan = payload.dig("plan")
        billing_price = nil
        item = payload.dig("items", "data", 0)
        if item
          price_id = item.dig("price", "id")
          billing_price = SubscriptionBillingPrice.active.for_provider(:stripe).find_by(provider_price_id: price_id)
        end

        {
          user: billing_customer.user,
          subscription: billing_price&.subscription,
          plan: plan,
          status: map_status(payload.dig("status")),
          provider_subscription_id: sub_id,
          current_period_start: period_ts(payload.dig("current_period_start"), item&.dig("current_period_start")),
          current_period_end: period_ts(payload.dig("current_period_end"), item&.dig("current_period_end")),
          billing_price: billing_price
        }
      end

      # Stripe subscription statuses -> app vocabulary.
      def map_status(provider_status)
        case provider_status
        when "active", "trialing" then "active"
        when "past_due", "unpaid", "incomplete", "incomplete_expired" then "past_due"
        when "canceled" then "cancelled"
        when "paused" then "paused"
        else "expired"
        end
      end

      def self.verify_webhook(payload, signature)
        Rails.logger.info "[Stripe Webhook] verify_webhook: payload size #{payload.bytesize} bytes, signature present: #{signature.present?}"
        api_event = ::Stripe::Webhook.construct_event(
          payload,
          signature,
          ENV.fetch("STRIPE_WEBHOOK_SECRET")
        )
        Rails.logger.info "[Stripe Webhook] verify_webhook: event=#{api_event.id} type=#{api_event.type}"
        api_event
      end

      private

      # The user's current Stripe subscription object (or nil when there is no
      # active provider subscription to change).
      def current_subscription(user)
        user_sub = user.user_subscriptions.current
                          .where(billing_provider: "stripe")
                          .where.not(provider_subscription_id: nil)
                          .first
        return nil if user_sub.nil?

        ::Stripe::Subscription.retrieve(user_sub.provider_subscription_id)
      end

      # Convert a Stripe epoch-seconds value to a Time, tolerating nil/0.
      def epoch_time(epoch)
        value = epoch.to_i
        return nil if value.zero?

        Time.at(value)
      end

      # The subscription item's billing period. stripe >= 15 removed the
      # top-level Subscription#current_period_start/end (they moved to the
      # subscription item), so always read them from items.data[0].
      def item_period(provider_sub)
        item = provider_sub.items.data[0]
        {
          start: epoch_time(item&.current_period_start),
          end: epoch_time(item&.current_period_end)
        }
      end

      # Convert an epoch to a Time, falling back to the secondary value.
      def period_ts(primary, secondary)
        epoch_time(primary) || epoch_time(secondary)
      end

      # Whether a Stripe invoice line item is a proration.
      #
      # stripe >= 19 moved the flag off the line item and onto its parent:
      # `line.parent.subscription_item_details.proration` for subscription
      # changes and `line.parent.invoice_item_details.proration` for proration
      # invoice items. Stripe documents this as the way to isolate prorations —
      # see https://docs.stripe.com/api/invoice-line-item/object#invoice_line_item_object-parent-subscription_item_details-proration
      #
      # We check both the parent chain AND the line's own attributes because the
      # `expand` parameter may or may not be in effect depending on how the object
      # was loaded.
      def proration_line?(line)
        parent = line.respond_to?(:parent) ? line.parent : nil
        parent_details = if parent
          [parent.try(:subscription_item_details), parent.try(:invoice_item_details)]
        else
          []
        end
        line_details = [
          line.try(:subscription_item_details),
          line.try(:invoice_item_details)
        ].compact

        (parent_details + line_details)
          .any? { |details| details.respond_to?(:proration) && details.proration == true }
      end

      # The subscription's most recent invoice, resolving the id-only form Stripe
      # returns when the `expand` request did not apply.
      def latest_invoice_for(subscription)
        invoice = subscription.respond_to?(:latest_invoice) ? subscription.latest_invoice : nil
        return nil if invoice.blank?
        return invoice if invoice.respond_to?(:status) # already a Stripe::Invoice

        ::Stripe::Invoice.retrieve(invoice)
      end
    end
  end
end

Billing::Providers.register(Billing::Providers::Stripe)