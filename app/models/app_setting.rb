# Global application configuration, backed by the app_settings table.
#
# Each setting is a key/value string pair; typed accessors coerce values and
# fall back to defaults when a key has never been set. This keeps feature
# toggles (currently "logs_enabled", more to come) persistable at runtime by
# admins via the Configuration page instead of redeploying.
class AppSetting < ApplicationRecord
  # Defaults used when a key has never been persisted.
  DEFAULTS = {
    "logs_enabled" => true,
    "use_test_email" => false,
    "test_email" => ENV["MAIL_REPLY_TO"],
    "mail_transport" => "auto",
    "show_taste_parameters" => "true",
    "analytics_diagnostics_enabled" => false,
    # Follow notifications (issue #192): master switch. Event publishing stops
    # when off — Follow rows and already-delivered notifications are preserved,
    # so toggling back on resumes exactly where it stopped.
    "follow_notifications_enabled" => true,
    # Hard account deletion master switch (issue #195). Disabled by default.
    "hard_delete_enabled" => false,
    # Wine Words review fee (IDENTITY_214): configurable per-bottle fee for
    # review packages. Default AUD 50.00.
    "wine_review_fee_amount" => ENV["WINE_REVIEW_FEE_AMOUNT"] || "50.00",
    "wine_review_fee_currency" => "AUD",
    # Invoice GST rate (IDENTITY_214 Phase 12): tax rate for PDF invoices.
    # Default 10% (Australia).
    "invoice_gst_rate" => "0.10",
    # Invoice "from" address (IDENTITY_214): sender used by InvoiceMailer.
    # Falls back to the INVOICE_FROM_EMAIL env var, then billing@winewords.com.
    "invoice_from_email" => ENV["INVOICE_FROM_EMAIL"].presence || ENV["MAIL_FROM"] || "billing@winewords.com"
  }.freeze

  validates :key, presence: true, uniqueness: true

  # Keys managed directly by the API and the Configuration page controls; they
  # must not be created/updated/deleted through the custom-settings CRUD.
  RESERVED_KEYS = %w[
    logs_enabled use_test_email test_email mail_transport
    wine_review_fee_amount wine_review_fee_currency
    invoice_gst_rate
    invoice_from_email
  ].freeze

  # Audit-trail master switch: when false, the Auditable concern skips
  # persisting Log/LogObject rows entirely (file logs are unaffected).
  def self.logs_enabled?
    boolean("logs_enabled")
  end

  # Email testing: when on, ApplicationMailer redirects every outgoing mail
  # (to/cc/bcc) to the configured test address instead of real recipients.
  def self.use_test_email?
    boolean("use_test_email")
  end

  def self.mail_transport
    string("mail_transport") || "auto"
  end

  def self.brevo_api_key
    string("brevo_api_key")
  end

  def self.resend_api_key
    string("resend_api_key")
  end

  def self.analytics_diagnostics_enabled?
    boolean("analytics_diagnostics_enabled")
  end

  # Follow notifications master switch (issue #192). See DEFAULTS above.
  def self.follow_notifications_enabled?
    boolean("follow_notifications_enabled")
  end

  # Hard account deletion master switch (issue #195). Disabled by default.
  def self.hard_delete_enabled?
    boolean("hard_delete_enabled")
  end

  # Hard account deletion master switch (issue #195). Disabled by default.
  def self.hard_delete_enabled?
    boolean("hard_delete_enabled")
  end

  def self.analytics_diagnostics_email
    string("analytics_diagnostics_email")
  end

  def self.analytics_diagnostics_frequency
    string("analytics_diagnostics_frequency")
  end

  def self.analytics_diagnostics_last_sent_at
    string("analytics_diagnostics_last_sent_at")
  end

  def self.analytics_diagnostics_next_send_at
    string("analytics_diagnostics_next_send_at")
  end

  def self.analytics_diagnostics_last_error
    string("analytics_diagnostics_last_error")
  end

  def self.analytics_diagnostics_last_successful_send_at
    string("analytics_diagnostics_last_successful_send_at")
  end

  def self.analytics_diagnostics_last_successful_send_count
    string("analytics_diagnostics_last_successful_send_count")
  end

  def self.analytics_diagnostics_last_successful_send_duration
    string("analytics_diagnostics_last_successful_send_duration")
  end

  def self.analytics_diagnostics_last_successful_send_size
    string("analytics_diagnostics_last_successful_send_size")
  end

  def self.test_email
    string("test_email")
  end

  def self.show_taste_parameters?
    boolean("show_taste_parameters")
  end

  # Wine Words review fee (IDENTITY_214): returns the configured amount as a
  # BigDecimal for safe monetary calculations. Defaults to 50.00 (AUD).
  def self.wine_review_fee_amount
    BigDecimal(string("wine_review_fee_amount") || DEFAULTS.fetch("wine_review_fee_amount"))
  rescue ArgumentError
    # Invalid stored value; fall back to default.
    BigDecimal(DEFAULTS.fetch("wine_review_fee_amount"))
  end

  # Wine Words review fee currency (IDENTITY_214): returns the configured
  # ISO 4217 currency code. Defaults to "AUD".
  def self.wine_review_fee_currency
    string("wine_review_fee_currency") || DEFAULTS.fetch("wine_review_fee_currency")
  end

  # Wine Words review fee amount formatted with exactly 2 decimal places for
  # JSON serialization (IDENTITY_214).
  def self.wine_review_fee_amount_formatted
    format("%.2f", wine_review_fee_amount)
  end

  # Invoice GST rate (IDENTITY_214 Phase 12): returns the configured
  # tax rate as a BigDecimal (e.g., 0.10 for 10%). Defaults to 0.10.
  def self.invoice_gst_rate
    BigDecimal(string("invoice_gst_rate") || DEFAULTS.fetch("invoice_gst_rate"))
  rescue ArgumentError
    BigDecimal(DEFAULTS.fetch("invoice_gst_rate"))
  end

  # Invoice "from" address (IDENTITY_214): the sender address used by
  # InvoiceMailer when the test transport is not active. Configurable from the
  # admin Configuration page; defaults to INVOICE_FROM_EMAIL env or
  # billing@winewords.com. A blank stored value self-heals to the default.
  def self.invoice_from_email
    string("invoice_from_email").presence || DEFAULTS.fetch("invoice_from_email")
  end

  # Validates an invoice "from" address: a single, plausible email address.
  # Returns the trimmed value on success, raises ArgumentError otherwise.
  def self.validate_invoice_from_email!(email)
    value = email.to_s.strip
    raise ArgumentError, "From email can't be blank" if value.empty?
    raise ArgumentError, "From email is not a valid email address" unless value.match?(URI::MailTo::EMAIL_REGEXP)

    value
  end

  # Validates that the amount is a non-negative decimal with at most 2 decimal
  # places and the currency is a known ISO 4217 code.
  def self.validate_wine_review_fee!(amount, currency)
    amount_bd = BigDecimal(amount.to_s)
    raise ArgumentError, "Fee amount must be non-negative" if amount_bd.negative?
    raise ArgumentError, "Fee amount must have at most 2 decimal places" if amount_bd.scale > 2

    currency = currency.to_s.upcase
    valid_currencies = %w[AUD USD EUR GBP NZD CAD CHF JPY]
    raise ArgumentError, "Unsupported currency: #{currency}" unless valid_currencies.include?(currency)

    [amount_bd, currency]
  rescue ArgumentError => e
    raise unless e.message.start_with?("Fee")
    raise
  rescue TypeError
    raise ArgumentError, "Invalid fee amount"
  end

  # Sets a key/value pair, creating the row if it doesn't exist yet. Returns the
  # value (cast to string) for convenience.

  def self.set!(key, value)
    setting = find_or_initialize_by(key: key.to_s)
    setting.value = value.to_s
    setting.save!
    value
  end

  # Coerces the stored string into a boolean. Accepts booleans as-is so the
  # controller can pass params straight through. A missing row falls back to
  # the default rather than nil (nil would read as "disabled").
  def self.boolean(key)
    raw = find_by(key: key.to_s)&.value
    return DEFAULTS.fetch(key.to_s, nil) if raw.nil?
    return raw unless raw.is_a?(String)

    ActiveModel::Type::Boolean.new.cast(raw)
  rescue ActiveRecord::StatementInvalid
    # Table may not exist yet (e.g. mid-migration boot); default safely.
    DEFAULTS.fetch(key.to_s, nil)
  end

  # Like boolean, for string-valued settings: a missing row falls back to the
  # default rather than nil.
  def self.string(key)
    raw = find_by(key: key.to_s)&.value
    return DEFAULTS.fetch(key.to_s, nil) if raw.nil?
    raw
  rescue ActiveRecord::StatementInvalid
    DEFAULTS.fetch(key.to_s, nil)
  end

  # Generic getter that returns the value with default fallback.
  # Used by controllers for feature flags and settings.
  def self.get(key, default = nil)
    raw = find_by(key: key.to_s)&.value
    return default if raw.nil?
    raw
  rescue ActiveRecord::StatementInvalid
    default
  end
end
