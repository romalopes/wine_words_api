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
    "analytics_diagnostics_enabled" => false,
    # Follow notifications (issue #192): master switch. Event publishing stops
    # when off — Follow rows and already-delivered notifications are preserved,
    # so toggling back on resumes exactly where it stopped.
    "follow_notifications_enabled" => true
  }.freeze

  validates :key, presence: true, uniqueness: true

  # Keys managed directly by the API and the Configuration page controls; they
  # must not be created/updated/deleted through the custom-settings CRUD.
  RESERVED_KEYS = %w[logs_enabled use_test_email test_email mail_transport].freeze

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
