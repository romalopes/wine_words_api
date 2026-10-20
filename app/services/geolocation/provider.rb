# frozen_string_literal: true

# Pluggable geolocation provider interface.
#
# Concrete providers (e.g. Geolocation::Ip2LocationProvider) implement `resolve`
# and return a Hash with `city`, `region`, and `country` keys, or `nil` if the
# location cannot be determined.
#
# This module provides the registry/factory so the concrete provider can be
# swapped without touching the login flow or the notification job.
module Geolocation
  module_function

  # The concrete provider is selected via the GEOLOCATION_PROVIDER env var
  # (default: "ip2location"). Set to "none" to disable lookups entirely —
  # the login details fall back to "Unknown" for location.
  def provider
    @provider ||= provider_for(ENV.fetch("GEOLOCATION_PROVIDER", "ip2location"))
  end

  def provider_for(name)
    case name.to_s.downcase
    when "ip2location"
      Geolocation::Ip2LocationProvider.new
    when "none"
      Geolocation::NullProvider.new
    else
      Rails.logger.warn("[geolocation] unknown provider '#{name}', falling back to NullProvider")
      Geolocation::NullProvider.new
    end
  end

  # Convenience delegate: resolve(ip) → Hash or nil.
  def resolve(ip)
    provider.resolve(ip)
  end
end
