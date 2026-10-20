# frozen_string_literal: true

# Null-object geolocation provider. Always returns nil so the calling service
# falls back to "Unknown". Used when GEOLOCATION_PROVIDER is unset, "none",
# or misconfigured.
module Geolocation
  class NullProvider
    def resolve(_ip)
      nil
    end
  end
end
