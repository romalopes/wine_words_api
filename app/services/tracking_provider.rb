# Carrier-independent shipment tracking.
#
# The package workflow never depends on a carrier: tracking data is optional and
# a reviewer can always maintain it by hand. Providers are resolved from the
# value stored in shipment_trackings.provider ("manual", "australia_post") — or
# loosely from the carrier name — and every provider answers the same
# normalised contract:
#
#   track(number) => {
#     status:                String or nil,  # carrier status text
#     status_updated_at:     Time or nil,
#     estimated_delivery_at: Time or nil,
#     delivered_at:          Time or nil,    # informational only
#     url:                   String or nil,  # human tracking page
#     events: [ { external_id:, status:, event_at:, location:, message:, raw_data: } ]
#   }
#
# A provider NEVER raises into the workflow: an unreachable carrier API or a
# missing credential yields an empty result, leaving whatever the reviewer
# recorded authoritative. Note that `delivered_at` must never mark a package as
# arrived — only a person confirms that the wines physically turned up.
module TrackingProvider
  MANUAL = "manual".freeze
  AUSTRALIA_POST = "australia_post".freeze

  # Accepted spellings of the Australia Post carrier (normalised comparison).
  AUSTRALIA_POST_ALIASES = %w[
    australia_post auspost aus_post australiapost australia-post
  ].freeze

  class << self
    # The provider implementation for a stored provider key or carrier name.
    def for(provider)
      key_for(provider) == AUSTRALIA_POST ? AustraliaPost.new : Manual.new
    end

    # Normalises any provider key / carrier name to the value stored in
    # shipment_trackings.provider. Unknown carriers fall back to "manual".
    def key_for(provider)
      return AUSTRALIA_POST if AUSTRALIA_POST_ALIASES.include?(normalize(provider))

      MANUAL
    end

    # Whether the Australia Post API can actually be called (a key is set).
    def australia_post_configured?
      AustraliaPost.configured?
    end

    # Registered providers, keyed by their stored value.
    def registry
      { MANUAL => Manual, AUSTRALIA_POST => AustraliaPost }
    end

    private

    def normalize(provider)
      provider.to_s.strip.downcase.tr(" ", "_")
    end
  end
end
