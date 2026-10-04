# frozen_string_literal: true

require_relative "http_mail_delivery"

# ActionMailer / Mail delivery adapter that sends through Resend's transactional
# HTTP API (POST https://api.resend.com/emails) instead of an SMTP server. Like
# the Brevo adapter it exists because Render's free plan blocks outbound SMTP
# ports 25/465/587 — HTTPS (443) is always allowed.
#
# Resend-specific parts live here (endpoint, Bearer auth, field names, error
# hints); the shared HTTP/Mail plumbing comes from HttpMailDelivery. The mail
# pipeline stays provider-agnostic: Devise, controllers and mailers only build
# a Mail::Message and call deliver_later (see lib/mail_transport.rb).
#
# Note: Resend requires a *verified domain* before it can send to real
# recipients — see https://resend.com/domains.
class ResendDelivery
  include HttpMailDelivery

  # Raised for missing configuration, transport failures (e.g. timeouts) and
  # non-2xx API responses; surfaced in the job log by
  # config.action_mailer.raise_delivery_errors = true.
  class Error < StandardError; end

  ENDPOINT = URI("https://api.resend.com/emails")
  PROVIDER = "Resend"

  # Resend's error body says what went wrong but not what to do about it. In
  # Render's log stream there is no shell and no browser, so these hints turn
  # an opaque 401/403 into a concrete, one-click fix.
  API_HINTS = [
    {
      match: ->(code, _body) { code == "401" },
      hint: "Resend rejected the API key. Check RESEND_API_KEY " \
            "(https://resend.com/api-keys)."
    },
    {
      match: ->(_code, body) { body.match?(/domain/i) && body.match?(/verif/i) },
      hint: "Resend requires a verified sending domain. Add one at " \
            "https://resend.com/domains and send from an address on that domain."
    }
  ].freeze

  def initialize(settings)
    @api_key = settings[:api_key]
    @open_timeout = settings[:open_timeout] || HttpMailDelivery::DEFAULT_TIMEOUT
    @read_timeout = settings[:read_timeout] || HttpMailDelivery::DEFAULT_TIMEOUT
  end

  def deliver!(mail)
    raise Error, "RESEND_API_KEY is not configured" if @api_key.blank?

    post_json(
      endpoint: ENDPOINT,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      payload: payload_for(mail),
      error_class: Error,
      provider: PROVIDER,
      hints: API_HINTS,
      open_timeout: @open_timeout,
      read_timeout: @read_timeout
    )
    true
  rescue Error
    raise
  rescue StandardError => e
    # Wrap transport-level errors (Net::OpenTimeout, SocketError, ...) so the
    # job log clearly attributes the failure to the Resend transport.
    raise Error, "Resend delivery failed: #{e.class}: #{e.message}"
  end

  # Pure Mail::Message -> Resend JSON payload mapping. Public so specs can
  # assert the transformation without touching the network.
  def payload_for(mail)
    payload = {
      from: formatted_address(mail[:from]&.decoded),
      to: recipient_emails(mail.to),
      subject: mail.subject.to_s
    }

    payload[:cc] = recipient_emails(mail.cc) if mail.cc.present?
    payload[:bcc] = recipient_emails(mail.bcc) if mail.bcc.present?

    reply_to = formatted_address(mail[:reply_to]&.decoded)
    payload[:reply_to] = reply_to if reply_to

    html, text = bodies(mail)
    payload[:html] = html if html.present?
    payload[:text] = text if text.present?

    attachments = base64_attachments(mail)
    payload[:attachments] = attachments if attachments.any?

    payload
  end

  private

  # "Wine Words <romalopes@gmail.com>" for Resend's string `from`/`reply_to`.
  def formatted_address(raw)
    address = parse_address(raw)
    return nil if address.nil?
    return address.address if address.display_name.blank?

    "#{address.display_name} <#{address.address}>"
  end
end
