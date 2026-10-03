# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "uri"

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
# they never know whether the transport is Brevo, Gmail SMTP, SendGrid, Resend
# or the :file test fallback. Swapping providers is a configuration change
# (see config/application.rb and config/environments/*), not a code change.
class BrevoDelivery
  # Raised for missing configuration, transport failures (e.g. timeouts) and
  # non-2xx API responses. With config.action_mailer.raise_delivery_errors = true
  # the message surfaces in the job log (Render's log stream) instead of being
  # swallowed, matching how the old SMTP failures were reported.
  class Error < StandardError; end

  ENDPOINT = URI("https://api.brevo.com/v3/smtp/email")
  DEFAULT_TIMEOUT = 10

  def initialize(settings)
    @api_key = settings[:api_key]
    @open_timeout = settings[:open_timeout] || DEFAULT_TIMEOUT
    @read_timeout = settings[:read_timeout] || DEFAULT_TIMEOUT
  end

  def deliver!(mail)
    raise Error, "BREVO_API_KEY is not configured" if @api_key.blank?

    http_post(payload_for(mail))
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
      sender: single_address(mail[:from]&.decoded),
      to: recipient_list(mail.to),
      subject: mail.subject.to_s
    }

    payload[:cc] = recipient_list(mail.cc) if mail.cc.present?
    payload[:bcc] = recipient_list(mail.bcc) if mail.bcc.present?

    reply_to = single_address(mail[:reply_to]&.decoded)
    payload[:replyTo] = reply_to if reply_to

    html, text = bodies(mail)
    payload[:htmlContent] = html if html.present?
    payload[:textContent] = text if text.present?

    files = mail.attachments.map do |att|
      { name: att.filename, content: Base64.strict_encode64(att.body.decoded) }
    end
    payload[:attachment] = files if files.any?

    payload
  end

  private

  # "Wine Words <romalopes@gmail.com>" => { email: ..., name: ... }
  def single_address(raw)
    return nil if raw.blank?

    address = Mail::Address.new(raw)
    return nil if address.address.blank?

    result = { email: address.address }
    result[:name] = address.display_name if address.display_name.present?
    result
  end

  def recipient_list(addresses)
    Array(addresses).map { |email| { email: email } }
  end

  def bodies(mail)
    if mail.multipart?
      [ mail.html_part&.body&.decoded, mail.text_part&.body&.decoded ]
    elsif mail.content_type.to_s.include?("text/html")
      [ mail.body.decoded, nil ]
    else
      [ nil, mail.body.decoded ]
    end
  end

  def build_request(payload)
    request = Net::HTTP::Post.new(ENDPOINT)
    request["Content-Type"] = "application/json"
    request["api-key"] = @api_key
    request.body = JSON.generate(payload)
    request
  end

  def http_post(payload)
    request = build_request(payload)
    response = Net::HTTP.start(
      ENDPOINT.host,
      ENDPOINT.port,
      use_ssl: true,
      open_timeout: @open_timeout,
      read_timeout: @read_timeout
    ) { |http| http.request(request) }

    return response if response.is_a?(Net::HTTPSuccess)

    raise Error, "Brevo API responded #{response.code}: #{response.body}"
  end
end
