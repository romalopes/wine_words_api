# Tracking state and its provider event history. `provider_configured` tells
# the UI whether a Refresh can actually reach the carrier, so it can explain why
# nothing changed instead of appearing broken.
class ShipmentTrackingSerializer
  def initialize(tracking, base_url = nil)
    @tracking = tracking
    @base_url = base_url
  end

  def as_json
    {
      wine_package_id: @tracking.wine_package_id,
      carrier: @tracking.carrier,
      number: @tracking.number,
      url: @tracking.url,
      provider: @tracking.provider,
      provider_configured: provider_configured?,
      status: @tracking.status,
      status_updated_at: iso(@tracking.status_updated_at),
      estimated_delivery_at: iso(@tracking.estimated_delivery_at),
      delivered_at: iso(@tracking.delivered_at),
      delivered: @tracking.delivered?,
      events: events,
      created_at: iso(@tracking.created_at),
      updated_at: iso(@tracking.updated_at)
    }
  end

  private

  def provider_configured?
    @tracking.provider_impl.configured?
  rescue StandardError
    false
  end

  def events
    @tracking.wine_package.shipment_tracking_events.chronological.map do |event|
      {
        id: event.id,
        status: event.status,
        event_at: iso(event.event_at),
        location: event.location,
        message: event.message,
        external_id: event.external_id,
        created_at: iso(event.created_at)
      }
    end
  end

  def iso(time)
    time&.iso8601
  end
end
