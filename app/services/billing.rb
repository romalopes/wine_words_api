# Generic, provider-independent billing layer.
#
# The application talks to billing through this module only. It exposes
# application-level operations (checkout, portal, customer, subscription) and
# resolves the configured billing provider. Stripe-specific code lives under
# Billing::Providers and is never referenced from controllers/models directly.
module Billing
  AVAILABLE_PROVIDERS = %w[stripe manual none].freeze

  # The active provider, resolved from BILLING_PROVIDER env. Stripe is only
  # usable when its secret key is present (so local dev without keys still
  # works with :manual/:none).
  def self.provider
    configured = ENV["BILLING_PROVIDER"].to_s.strip
    return :none if configured.blank? || configured == "none"
    return :stripe if configured == "stripe" && stripe_enabled?
    return :manual if configured == "stripe" # stripe requested but no key

    # For any other provider, use it if a registered adapter exists.
    sym = configured.to_sym
    Billing::Providers.find(sym) ? sym : :manual
  end

  # Whether any billing provider (not manual/none) is active.
  def self.configured?
    provider != :none && provider != :manual
  end

  # Whether Stripe specifically is the active provider (has a secret key).
  def self.stripe_enabled?
    stripe_configured?
  end

  def self.stripe_configured?
    Billing::Providers::Stripe.configured?
  end

  # Named generic operations, delegating to the resolved provider.
  def self.checkout; Billing::Checkout; end
  def self.confirm_checkout; Billing::ConfirmCheckout; end
  def self.customer; Billing::Customer; end
  def self.subscription; Billing::Subscription; end
  def self.portal; Billing::Portal; end

  # The provider object that implements the Billing::Providers::Base contract.
  def self.adapter
    klass = Billing::Providers.find(provider)
    raise Billing::Error, "No billing provider configured for: #{provider}" unless klass
    klass.new
  end
end