module TrackingProvider
  # The always-available provider: nothing is fetched, and the reviewer's own
  # carrier / number / url / status stay authoritative.
  #
  # Because ShipmentTracking#apply_result! only writes the keys a provider
  # returns, a refresh through this provider never clears manually entered data.
  class Manual
    KEY = "manual".freeze

    def key
      KEY
    end

    def configured?
      true
    end

    def track(_number)
      { events: [] }
    end
  end
end
