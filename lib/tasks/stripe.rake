# frozen_string_literal: true

# Sync WinePrediction subscription plans to Stripe Products and Prices.
#
# Usage:
#   bundle exec rails stripe:sync_prices
#
# What it does:
#   1. Reads every active, visible, paid Subscription.
#   2. For each, finds or creates a Stripe Product (name = plan name).
#   3. Creates an annual recurring Stripe Price in AUD (SKUs like "Consumer –
#      Annual").  If the plan already has an active SubscriptionBillingPrice
#      whose provider_price_id still points to a live Stripe Price with the
#      same amount_cents and currency, it is left alone.
#   4. Saves provider_product_id and provider_price_id to
#      SubscriptionBillingPrice (provider: stripe, interval: year).
#
# This task is idempotent – run it as often as you like.

namespace :stripe do
  desc "Create or update Stripe Products and Prices for paid WinePrediction plans"
  task sync_prices: :environment do
    # Force autoload + self-registration of the Stripe provider so model
    # validation (provider inclusion check) passes when writing billing prices.
    Billing::Providers::Stripe

    unless ENV["STRIPE_SECRET_KEY"].present?
      puts "❌  STRIPE_SECRET_KEY is not set. Skipping Stripe sync."
      next
    end

    paid_plans = Subscription
      .where(active: true, visible: true)
      .reject(&:free?)

    if paid_plans.empty?
      puts "No paid, active, visible plans found. Nothing to sync."
      next
    end

    puts "Syncing #{paid_plans.size} plan(s) to Stripe ...\n\n"

    paid_plans.each do |plan|
      sync_plan(plan)
    end

    puts "\nDone."
  end

  private

    def sync_plan(plan)
      print "  #{plan.name} (AUD $#{'%.2f' % (plan.yearly_price_cents / 100.0)}) ... "

      existing = plan.subscription_billing_prices
                     .find_by(provider: "stripe", billing_interval: "year", active: true)

      # If the existing price is still current, skip.
      if existing && existing.amount_cents == plan.yearly_price_cents &&
         existing.currency == "AUD" && price_exists_on_stripe?(existing.provider_price_id)
        puts "already current (price #{existing.provider_price_id})."
        return
      end

      # Determine the product id – reuse an existing Stripe product id if one
      # is already stored for this plan.
      product_id = plan.subscription_billing_prices
                       .find_by(provider: "stripe")&.provider_product_id

      # Create or retrieve the Stripe Product.
      if product_id
        Stripe::Product.retrieve(product_id)
        product = Stripe::Product.update(product_id, { name: plan.name })
      else
        product = Stripe::Product.create({
          name: plan.name,
          description: plan.description.presence,
          active: true,
          metadata: {
            wine_prediction_plan_id: plan.id.to_s,
            wine_prediction_plan_slug: plan.slug,
          }
        })
      end

      product_id = product.id

      # Create the annual recurring Price in AUD.
      price = Stripe::Price.create({
        product: product_id,
        unit_amount: plan.yearly_price_cents,
        currency: "aud",
        recurring: { interval: "year" },
        nickname: "#{plan.name} – Annual",
        metadata: {
          wine_prediction_plan_id: plan.id.to_s,
          wine_prediction_plan_slug: plan.slug,
        }
      })

      # Deactivate any old stripe price records so only the latest is active.
      plan.subscription_billing_prices
          .where(provider: "stripe", billing_interval: "year")
          .update_all(active: false)

      # Upsert the active billing price record.
      rec = plan.subscription_billing_prices
                .create_with(
                  provider_product_id: product_id,
                  amount_cents: plan.yearly_price_cents,
                  currency: "AUD",
                  billing_interval: "year",
                  active: true
                )
                .find_or_create_by!(
                  provider: "stripe",
                  provider_price_id: price.id
                )
      rec.update!(active: true, amount_cents: plan.yearly_price_cents)

      puts "created / updated (price #{price.id})."
    end

    # Check whether a Stripe Price still exists and is active.  Returns true
    # when Stripe can't be reached or the price doesn't exist (triggers a
    # re-create).
    def price_exists_on_stripe?(price_id)
      Stripe::Price.retrieve(price_id)
      true
    rescue Stripe::StripeError
      false
    end
end