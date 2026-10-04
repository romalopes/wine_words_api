# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "uri"

# Shared plumbing for ActionMailer delivery adapters that POST a JSON payload
# to a transactional-email HTTP API (Brevo, Resend, ...).
#
# A provider class includes this module and keeps only what is genuinely
# different: its endpoint, auth header, payload field names and error hints.
# Everything that would otherwise be copy-pasted between providers —
# Mail::Message body/address extraction, attachment encoding, the HTTPS request
# itself, non-2xx handling and the hint lookup — lives here, so a fix or
# improvement applies to every provider at once.
#
# The module is stdlib-only and never touches ActionMailer configuration;
# lib/mail_transport.rb decides which provider is active.
module HttpMailDelivery
  DEFAULT_TIMEOUT = 10

  # Mail::Address for a raw header value ("Wine Words <a@b.com>"), or nil when
  # the value is blank or carries no address part.
  def parse_address(raw)
    return nil if raw.to_s.strip.empty?

    address = Mail::Address.new(raw)
    return nil if address.address.to_s.strip.empty?

    address
  end

  # Plain recipient addresses from a to/cc/bcc header, as strings.
  def recipient_emails(addresses)
    Array(addresses).map { |email| email.to_s.strip }.reject(&:empty?)
  end

  # [html, text] body parts of a Mail::Message; either may be nil.
  def bodies(mail)
    if mail.multipart?
      [ mail.html_part&.body&.decoded, mail.text_part&.body&.decoded ]
    elsif mail.content_type.to_s.include?("text/html")
      [ mail.body.decoded, nil ]
    else
      [ nil, mail.body.decoded ]
    end
  end

  # Attachments base64-encoded for JSON APIs: [{ filename:, content: }]
  def base64_attachments(mail)
    mail.attachments.map do |attachment|
      { filename: attachment.filename, content: Base64.strict_encode64(attachment.body.decoded) }
    end
  end

  # POSTs the payload and returns the Net::HTTP response. Raises error_class on
  # a non-2xx status, appending the first matching provider hint.
  def post_json(endpoint:, headers:, payload:, error_class:, provider:, hints:,
                open_timeout: DEFAULT_TIMEOUT, read_timeout: DEFAULT_TIMEOUT)
    request = Net::HTTP::Post.new(endpoint)
    request["Content-Type"] = "application/json"
    headers.each { |name, value| request[name] = value }
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(
      endpoint.host,
      endpoint.port,
      use_ssl: true,
      open_timeout: open_timeout,
      read_timeout: read_timeout
    ) { |http| http.request(request) }

    return response if response.is_a?(Net::HTTPSuccess)

    raise error_class, error_message(response, provider: provider, hints: hints)
  end

  def error_message(response, provider:, hints:)
    body = response.body.to_s
    message = "#{provider} API responded #{response.code}: #{body}"
    hint = hints.find { |candidate| candidate[:match].call(response.code.to_s, body) }&.fetch(:hint)
    hint ? "#{message} — #{hint}" : message
  end
end
