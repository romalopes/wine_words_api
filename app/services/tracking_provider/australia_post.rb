require "digest"

module TrackingProvider
  # Australia Post tracking.
  #
  # Two independent capabilities, so the workflow degrades gracefully:
  #   * a human-readable tracking URL — always available, never hard-coded per
  #     carrier, configurable through AUSTRALIA_POST_TRACKING_URL;
  #   * the tracking API — called ONLY when AUSTRALIA_POST_API_KEY is present
  #     (endpoint overridable with AUSTRALIA_POST_API_URL).
  #
  # Without a key it behaves like the manual provider but still records the URL,
  # so nothing about the package workflow depends on a carrier account.
  class AustraliaPost
    KEY = "australia_post".freeze
    DEFAULT_TRACKING_URL = "https://auspost.com.au/mypost/track/#/details/".freeze
    DEFAULT_API_URL = "https://digitalapi.auspost.com.au/shipping/v1/track".freeze
    TIMEOUT = 5

    class << self
      def api_key
        ENV["AUSTRALIA_POST_API_KEY"].presence
      end

      def configured?
        api_key.present?
      end
    end

    def key
      KEY
    end

    def configured?
      self.class.configured?
    end

    # Human tracking page for a consignment number.
    def tracking_url(number)
      return nil if number.blank?

      "#{tracking_url_base}#{number}"
    end

    def track(number)
      result = { events: [], url: tracking_url(number) }
      return result if number.blank? || !configured?

      payload = fetch(number)
      return result if payload.blank?

      # Pass the number through so the tracking URL survives the merge.
      result.merge(normalize(payload, number))
    end

    # Maps an Australia Post tracking payload onto the normalised contract.
    # Public so it can be exercised without any network access.
    def normalize(payload, number = nil)
      payload = (payload || {}).with_indifferent_access
      first = Array(payload[:tracking_results]).first || {}
      events = extract_events(first)
      status = first[:status].presence

      {
        status: status,
        status_updated_at: events.filter_map { |event| event[:event_at] }.max,
        estimated_delivery_at: parse_time(first[:estimated_delivery_date]),
        delivered_at: delivered_at(status, events),
        url: tracking_url(number),
        events: events
      }
    end

    private

    def tracking_url_base
      ENV["AUSTRALIA_POST_TRACKING_URL"].presence || DEFAULT_TRACKING_URL
    end

    def api_url
      ENV["AUSTRALIA_POST_API_URL"].presence || DEFAULT_API_URL
    end

    def extract_events(tracking_result)
      Array(tracking_result[:consignments]).flat_map do |consignment|
        Array(consignment[:events]).map { |event| normalize_event(event) }
      end
    end

    def normalize_event(event)
      event = (event || {}).with_indifferent_access
      happened_at = parse_time(event[:date])
      description = event[:description].presence
      location = event[:location]

      {
        external_id: event[:id].presence || event_fingerprint(happened_at, location, description),
        status: description || "update",
        event_at: happened_at,
        location: location,
        message: description,
        raw_data: event.to_h
      }
    end

    # Stable identity for carriers that return no event id, so re-importing the
    # same payload stays idempotent.
    def event_fingerprint(happened_at, location, description)
      Digest::SHA256.hexdigest([ happened_at, location, description ].join("|"))
    end

    def delivered_at(status, events)
      return nil unless status.to_s.match?(/deliver/i)

      events.filter_map { |event| event[:event_at] }.max
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # Never raises: a carrier outage must not break the package workflow.
    def fetch(number)
      uri = URI.parse(api_url)
      uri.query = URI.encode_www_form(tracking_ids: number)

      request = Net::HTTP::Get.new(uri.request_uri)
      request["AUTH-KEY"] = self.class.api_key
      request["Accept"] = "application/json"

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[tracking] australia_post responded #{response.code}")
        return nil
      end

      JSON.parse(response.body.to_s)
    rescue StandardError => e
      Rails.logger.error("[tracking] australia_post lookup failed: #{e.class}")
      nil
    end
  end
end
