# frozen_string_literal: true

# Concrete geolocation provider backed by IP2Location.io (https://www.ip2location.io).
#
# Requires the IP2LOCATION_API_KEY environment variable (free plan allows 50k
# queries/month). When the key is missing, the API call fails, or times out,
# `resolve` returns nil — a geolocation outage must never fail a login or the
# notification job.
#
# Sample response (GET https://api.ip2location.io/?ip=8.8.8.8&key=…):
#   {
#     "ip" => "8.8.8.8",
#     "country_code" => "US",
#     "country_name" => "United States of America",
#     "region_name" => "California",
#     "city_name" => "Mountain View",
#     ...
#   }
module Geolocation
  class Ip2LocationProvider
    API_URL = ENV.fetch("IP2LOCATION_API_URL", "https://api.ip2location.io/v2/")
    TIMEOUT = 5

    def resolve(ip)
      return nil if ip.blank?
      return nil if ENV["IP2LOCATION_API_KEY"].blank?

      uri = URI.parse(API_URL)
      uri.query = URI.encode_www_form(ip: ip, key: ENV["IP2LOCATION_API_KEY"])

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      response = http.request(Net::HTTP::Get.new(uri.request_uri))
      return nil unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body.to_s)
      return nil unless body.is_a?(Hash) && body["ip"].present?

      {
        city: body["city_name"].presence,
        region: body["region_name"].presence,
        country: body["country_name"].presence
      }
    rescue StandardError => e
      # Never raise: a geolocation outage must not break login notifications.
      Rails.logger.warn("[geolocation] ip2location lookup failed: #{e.class}")
      nil
    end
  end
end
