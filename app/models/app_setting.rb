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
    "test_email" => "romalopes@yahoo.com.br"
  }.freeze

  validates :key, presence: true, uniqueness: true

  # Keys managed directly by the API and the Configuration page controls; they
  # must not be created/updated/deleted through the custom-settings CRUD.
  RESERVED_KEYS = %w[logs_enabled use_test_email test_email].freeze

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
    return DEFAULTS.fetch(key.to_s) if raw.nil?
    return raw unless raw.is_a?(String)

    ActiveModel::Type::Boolean.new.cast(raw)
  rescue ActiveRecord::StatementInvalid
    # Table may not exist yet (e.g. mid-migration boot); default safely.
    DEFAULTS[key.to_s]
  end

  # Like boolean, for string-valued settings: a missing row falls back to the
  # default rather than nil.
  def self.string(key)
    raw = find_by(key: key.to_s)&.value
    return DEFAULTS.fetch(key.to_s) if raw.nil?
    raw
  rescue ActiveRecord::StatementInvalid
    DEFAULTS[key.to_s]
  end
end
