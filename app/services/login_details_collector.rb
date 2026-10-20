# frozen_string_literal: true

# Extracts login metadata (IP, user agent, browser/OS/device, location) from a
# Rails request into a serialisable LoginDetails value object.
#
#   LoginDetailsCollector.collect(
#     request,
#     login_method: "password"
#   )
#   # => #<LoginDetails ip_address: "203.0.113.10", browser: "Chrome", ...>
#
# Never raises: any extraction failure degrades the field to "Unknown" so a
# transient user-agent or geolocation problem can never break a login response.
class LoginDetailsCollector
  UNKNOWN = LoginDetails::UNKNOWN

  def self.collect(request, login_method: UNKNOWN)
    new(request, login_method: login_method).collect
  end

  def initialize(request, login_method: UNKNOWN)
    @request = request
    @login_method = login_method
  end

  def collect
    LoginDetails.new(
      ip_address: client_ip,
      user_agent: raw_user_agent,
      browser: browser,
      browser_version: browser_version,
      os: os,
      device: device,
      location: location,
      login_method: login_method,
      logged_in_at: Time.current,
      mobile: mobile?
    )
  end

  private

  attr_reader :request, :login_method

  # `ActionDispatch::Request#remote_ip` respects ActionDispatch::RemoteIp,
  # which in turn honours the `config.action_dispatch.trusted_proxies` and
  # `config.action_dispatch.ip_spoofing_check` settings. In production behind
  # Render / a load balancer those settings must be configured correctly or
  # `remote_ip` will report the LB address instead of the real client.
  def client_ip
    request.remote_ip.presence || UNKNOWN
  rescue StandardError => e
    log_degradation("client_ip", e)
    UNKNOWN
  end

  def raw_user_agent
    request.user_agent.to_s.presence || UNKNOWN
  rescue StandardError => e
    log_degradation("user_agent", e)
    UNKNOWN
  end

  # Uses the existing `useragent` gem. All accessors degrade to UNKNOWN on any
  # parsing error so a malformed header can never raise out of the login flow.
  # All methods return "Unknown" if the UA header was missing or parsing failed.
  def browser
    return UNKNOWN unless agent
    agent.browser.presence || UNKNOWN
  rescue StandardError => e
    log_degradation("browser", e)
    UNKNOWN
  end

  def browser_version
    return UNKNOWN unless agent
    agent.version.presence || UNKNOWN
  rescue StandardError => e
    log_degradation("browser_version", e)
    UNKNOWN
  end

  def os
    return UNKNOWN unless agent
    agent.os.presence || UNKNOWN
  rescue StandardError => e
    log_degradation("os", e)
    UNKNOWN
  end

  # The `useragent` gem has no `device` accessor, so the device class is
  # derived from the platform and the mobile flag (iOS/Android => Mobile,
  # everything else => Desktop). Never raises.
  def device
    return UNKNOWN unless agent

    if agent.mobile?
      agent.platform.presence || "Mobile"
    else
      "Desktop"
    end
  rescue StandardError => e
    log_degradation("device", e)
    UNKNOWN
  end

  # Delegates to the configured geolocation provider, which returns a
  # `{ city:, region:, country: }` hash or nil. The hash is formatted into a
  # single human-readable string (e.g. "Mountain View, California, United
  # States of America"). Degrades to "Unknown" when the provider is not
  # configured, times out or errors — a missing location must never block or
  # slow down authentication.
  def location
    geo = Geolocation::Provider.resolve(client_ip)
    return UNKNOWN if geo.nil?

    [geo[:city], geo[:region], geo[:country]].compact.reject(&:blank?).join(", ").presence || UNKNOWN
  rescue StandardError => e
    log_degradation("location", e)
    UNKNOWN
  end

  def mobile?
    agent.mobile?
  rescue StandardError
    false
  end

  def agent
    @agent ||= UserAgent.parse(raw_user_agent)
  end

  def log_degradation(field, error)
    Rails.logger.warn(
      "[login_details] #{field} extraction failed, degrading to '#{UNKNOWN}': #{error.class}"
    )
  end
end
