# Stripe configuration for billing.
#
# Reads credentials from the environment (never committed). Stripe-specific
# integration code lives under Billing::Providers::Stripe and is only
# activated when STRIPE_SECRET_KEY is set (see Billing module).
Stripe.api_key = ENV["STRIPE_SECRET_KEY"] if ENV["STRIPE_SECRET_KEY"].present?
# NOTE: The provider self-registers via Billing::Providers::Stripe autoloading.
# This is triggered explicitly in the stripe:sync_prices rake task.  Don't
# reference Billing::Providers::Stripe here – the Billing module lives under
# app/services/ and Zeitwerk hasn't initialised autoload paths yet when the
# initializer runs.