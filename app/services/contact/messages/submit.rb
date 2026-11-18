# Public contact-form intake (IDENTITY_209 Phase 1).
#
# Order matters and mirrors the plan: honeypot -> Turnstile -> validation ->
# persist -> enqueue delivery. Nothing internal is ever returned to the caller;
# the controller only sees this Result.
#
# The message is saved before any job is enqueued. Delivery work therefore
# never runs inside a transaction and a queue outage cannot lose the message —
# it is logged (and reported to Sentry) while the visitor still gets success.
module Contact
  module Messages
    class Submit
      Result = Struct.new(:status, :contact_message, :error_codes, keyword_init: true)

      PERMITTED_ATTRIBUTES = %i[name email contact_type subject message].freeze

      def self.call(params:, remote_ip: nil)
        new(params: params, remote_ip: remote_ip).call
      end

      def initialize(params:, remote_ip: nil)
        @params = params
        @remote_ip = remote_ip
      end

      def call
        # A filled honeypot is discarded silently: the bot gets the same
        # response as a person, but nothing is stored or delivered.
        if honeypot_filled?
          Rails.logger.warn("[Contact::Messages::Submit] honeypot discarded a submission")
          return Result.new(status: :discarded)
        end

        verification = Turnstile::Verifier.call(token: turnstile_token, remote_ip: @remote_ip)
        unless verification.success?
          Rails.logger.warn(
            "[Contact::Messages::Submit] turnstile rejected: #{verification.error_codes.join(',')}"
          )
          return Result.new(status: :turnstile_failed, error_codes: verification.error_codes)
        end

        message = ContactMessage.new(attributes)
        return Result.new(status: :invalid, contact_message: message) unless message.save

        enqueue_delivery(message)
        Result.new(status: :created, contact_message: message)
      end

      private

      def attributes
        PERMITTED_ATTRIBUTES.index_with { |key| @params[key] }
      end

      def honeypot_filled?
        @params[:website].to_s.strip.present?
      end

      def turnstile_token
        @params[:turnstile_token].to_s.strip.presence
      end

      def enqueue_delivery(message)
        ContactMessages::Recipients.emails.each do |recipient|
          ContactMessages::EmailJob.perform_later(message.id, recipient)
        end
        ContactMessages::NotifyStaffJob.perform_later(message.id)

        Rails.logger.info("[Contact::Messages::Submit] message #{message.id} accepted")
      rescue StandardError => e
        # The row is committed; never turn a queue problem into a lost message
        # or a visitor-facing error. Ops monitors the log/Sentry event.
        Rails.logger.error(
          "[Contact::Messages::Submit] message #{message.id} delivery enqueue failed: " \
          "#{e.class}: #{e.message}"
        )
        Sentry.capture_exception(e) if defined?(Sentry)
      end
    end
  end
end
