# frozen_string_literal: true

# Pluggable geolocation provider factory. Concrete providers implement
# `resolve` and return a Hash with `city`, `region`, and `country` keys, or nil
# when a location cannot be determined.
module Geolocation
  module Provider
    module_function

    # The concrete provider is selected via GEOLOCATION_PROVIDER (default:
    # "ip2location"). Set it to "none" to disable lookups entirely.
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

    # Convenience delegate: resolve(ip) -> Hash or nil.
    def resolve(ip)
      provider.resolve(ip)
    end
  end
end
