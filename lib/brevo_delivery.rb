# frozen_string_literal: true

require_relative "http_mail_delivery"

# ActionMailer / Mail delivery adapter that sends through Brevo's transactional
# HTTP API (POST https://api.brevo.com/v3/smtp/email) instead of an SMTP
# server. Render's free plan blocks outbound traffic to SMTP ports 25/465/587,
# so delivery over HTTPS (port 443) is the only transport that works there.
#
# This class sits behind ActionMailer's delivery-method abstraction, which
# keeps the mail pipeline provider-agnostic:
#
#   Devise -> CustomDeviseMailer -> ActionMailer -> [delivery method] -> user
#
# Controllers and mailers only build a Mail::Message and call deliver_later;
# they never know whether the transport is Brevo, Resend, Gmail SMTP or the
# :file test fallback. Swapping providers is a configuration change (see
# config/application.rb, lib/mail_transport.rb and config/environments/*).
#
# Brevo-specific parts live here (endpoint, auth header, field names, error
# hints); the shared HTTP/Mail plumbing comes from HttpMailDelivery.
class BrevoDelivery
  include HttpMailDelivery

  # Raised for missing configuration, transport failures (e.g. timeouts) and
  # non-2xx API responses. With config.action_mailer.raise_delivery_errors = true
  # the message surfaces in the job log (Render's log stream) instead of being
  # swallowed, matching how the old SMTP failures were reported.
  class Error < StandardError; end

  ENDPOINT = URI("https://api.brevo.com/v3/smtp/email")
  PROVIDER = "Brevo"

  # Brevo's error body says what went wrong but not what to do about it. In
  # Render's log stream there is no shell and no browser, so these hints turn
  # an opaque 401/400 into a concrete, one-click fix.
  API_HINTS = [
    {
      match: ->(code, body) { code == "401" && body.match?(/unrecogni[sz]ed IP address/i) },
      hint: "Brevo rejected the caller's IP address. Either add it at " \
            "https://app.brevo.com/security/authorised_ips or turn OFF Brevo's " \
            "\"Authorized IPs\" security feature — the latter is required when " \
            "running on Render, whose outbound IPs are shared/dynamic."
    },
    {
      match: ->(_code, body) { body.match?(/sender/i) && body.match?(/verif/i) },
      hint: "Brevo requires a verified sender. Verify the From address under " \
            "Brevo → Senders & Domains (https://app.brevo.com/senders/domains)."
    }
  ].freeze

  def initialize(settings)
    @api_key = settings[:api_key]
    @open_timeout = settings[:open_timeout] || HttpMailDelivery::DEFAULT_TIMEOUT
    @read_timeout = settings[:read_timeout] || HttpMailDelivery::DEFAULT_TIMEOUT
  end

  def deliver!(mail)
    raise Error, "BREVO_API_KEY is not configured" if @api_key.blank?

    post_json(
      endpoint: ENDPOINT,
      headers: { "api-key" => @api_key },
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
    # job log clearly attributes the failure to the Brevo transport.
    raise Error, "Brevo delivery failed: #{e.class}: #{e.message}"
  end

  # Pure Mail::Message -> Brevo JSON payload mapping. Public so specs can
  # assert the transformation without touching the network.
  def payload_for(mail)
    payload = {
      sender: sender_address(mail[:from]&.decoded),
      to: recipient_list(mail.to),
      subject: mail.subject.to_s
    }

    payload[:cc] = recipient_list(mail.cc) if mail.cc.present?
    payload[:bcc] = recipient_list(mail.bcc) if mail.bcc.present?

    reply_to = sender_address(mail[:reply_to]&.decoded)
    payload[:replyTo] = reply_to if reply_to

    html, text = bodies(mail)
    payload[:htmlContent] = html if html.present?
    payload[:textContent] = text if text.present?

    files = base64_attachments(mail).map { |file| { name: file[:filename], content: file[:content] } }
    payload[:attachment] = files if files.any?

    payload
  end

  private

  # "Wine Words <romalopes@gmail.com>" => { email: ..., name: ... }
  def sender_address(raw)
    address = parse_address(raw)
    return nil if address.nil?

    result = { email: address.address }
    result[:name] = address.display_name if address.display_name.present?
    result
  end

  def recipient_list(addresses)
    recipient_emails(addresses).map { |email| { email: email } }
  end
end
