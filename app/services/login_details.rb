# frozen_string_literal: true

# Value object representing the details of a single successful login.
# Serialisable (Hash#as_json) so it can be passed to Active Job as arguments.
#
#   LoginDetails.new(
#     ip_address: "203.0.113.10",
#     user_agent: "Mozilla/5.0 ...",
#     browser: "Chrome",
#     browser_version: "120.0",
#     os: "macOS",
#     device: "Mac",
#     mobile: false,
#     location: "Lisbon, Portugal",
#     login_method: "password"
#   )
#
class LoginDetails
  UNKNOWN = "Unknown"

  attr_reader :ip_address, :user_agent, :browser, :browser_version, :os,
              :device, :location, :login_method, :logged_in_at

  def initialize(ip_address: UNKNOWN, user_agent: UNKNOWN, browser: UNKNOWN,
                 browser_version: UNKNOWN, os: UNKNOWN, device: UNKNOWN,
                 location: UNKNOWN, login_method: UNKNOWN, logged_in_at: nil,
                 mobile: false)
    @ip_address = ip_address.to_s.presence || UNKNOWN
    @user_agent = user_agent.to_s.presence || UNKNOWN
    @browser = browser.to_s.presence || UNKNOWN
    @browser_version = browser_version.to_s.presence || UNKNOWN
    @os = os.to_s.presence || UNKNOWN
    @device = device.to_s.presence || UNKNOWN
    @location = location.to_s.presence || UNKNOWN
    @login_method = login_method.to_s.presence || UNKNOWN
    @logged_in_at = logged_in_at || Time.current
    @mobile = ActiveModel::Type::Boolean.new.cast(mobile)
  end

  def mobile?
    @mobile
  end

  def serializable_hash
    {
      "ip_address" => ip_address,
      "user_agent" => user_agent,
      "browser" => browser,
      "browser_version" => browser_version,
      "os" => os,
      "device" => device,
      "location" => location,
      "login_method" => login_method,
      "logged_in_at" => logged_in_at.iso8601,
      "mobile" => @mobile
    }
  end

  def to_s
    "#{browser} #{browser_version} on #{os} (#{device}) from #{location} (#{ip_address})"
  end
end
