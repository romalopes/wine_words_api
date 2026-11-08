module WinePackages
  # Merged, viewer-scoped activity timeline for a WinePackage (issue #199 §5).
  #
  # Two event sources, never duplicated:
  #   * WinePackageEvent    — application activity (requested, accepted,
  #                           rejected, withdrawn, arrived, review published);
  #   * ShipmentTrackingEvent — raw carrier events, merged read-only.
  #
  # `internal` package events (editorial notes/decisions) are only included
  # for catalogue managers and the assigned reviewer. Producer members see the
  # shared milestones and the carrier history, never editorial-only entries.
  class Timeline
    def self.events(package, viewer:)
      new(package, viewer: viewer).events
    end

    def initialize(package, viewer:)
      @package = package
      @viewer = viewer
    end

    # Ordered, oldest first, with an explicit `source` so the UI can style
    # application milestones differently from carrier updates.
    def events
      (package_entries + carrier_entries)
        .sort_by { |entry| [ entry[:occurred_at] || Time.zone.at(0), entry[:id] || 0 ] }
    end

    private

    attr_reader :package, :viewer

    def package_entries
      scope = package.wine_package_events
      scope = scope.shared unless internal_visible?

      scope.chronological.map do |event|
        {
          id: event.id,
          source: "package",
          event_type: event.event_type,
          description: event.description,
          actor_id: event.actor_id,
          visibility: event.visibility,
          occurred_at: iso(event.occurred_at)
        }
      end
    end

    def carrier_entries
      package.shipment_tracking_events.chronological.map do |event|
        {
          id: event.id,
          source: "carrier",
          event_type: "shipment",
          status: event.status,
          description: event.location,
          message: event.message,
          occurred_at: iso(event.event_at)
        }
      end
    end

    # Catalogue managers (Admin/Editor) and the assigned reviewer see the
    # internal editorial events; everyone else sees shared events only.
    def internal_visible?
      viewer && (viewer.catalogue_manager? || package.reviewer_id == viewer.id)
    end

    def iso(time)
      time&.iso8601
    end
  end
end
