# Parses the contact-form delivery recipients (IDENTITY_209).
#
# CONTACT_NOTIFICATION_EMAILS is a comma (or semicolon) separated list in the
# Rails environment only:
#
#   CONTACT_NOTIFICATION_EMAILS=support@wine-words.com,admin@wine-words.com
#
# MAIL_REPLY_TO intentionally keeps its existing meaning (the Reply-To header
# used by every mailer); it is NOT a recipient list and is not read here.
#
# Rules: trim whitespace, downcase, drop blanks, reject invalid addresses and
# CR/LF header-injection attempts, deduplicate. Never raises — an empty result
# means "no recipients configured", which the caller treats as a logged,
# non-fatal condition (the message stays persisted either way).
module ContactMessages
  module Recipients
    MAX_EMAIL_LENGTH = 254
    HEADER_INJECTION = /[\r\n]/

    module_function

    def emails(env = ENV)
      raw = env["CONTACT_NOTIFICATION_EMAILS"].to_s
      candidates = raw.split(/[,;]/).map { |value| value.to_s.strip.downcase }.reject(&:empty?)

      valid = candidates.select { |value| valid_address?(value) }
      invalid_count = candidates.size - valid.size
      if invalid_count.positive?
        Rails.logger.warn(
          "[ContactMessages::Recipients] ignored #{invalid_count} invalid recipient(s)"
        )
      end

      result = valid.uniq
      if result.empty? && !Rails.env.test?
        Rails.logger.error(
          "[ContactMessages::Recipients] CONTACT_NOTIFICATION_EMAILS is not configured; " \
          "contact messages will be stored without an email notification"
        )
      end
      result
    end

    def valid_address?(value)
      return false if value.length > MAX_EMAIL_LENGTH
      return false if value.match?(HEADER_INJECTION)

      value.match?(URI::MailTo::EMAIL_REGEXP)
    end
  end
end
