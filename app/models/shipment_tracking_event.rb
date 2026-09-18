# Immutable-ish history for a package's shipment, keyed by the package itself
# (tracking is 1:1 with a package). `external_id` is the carrier's event id:
# the unique index on (wine_package_id, external_id) makes re-importing the
# same carrier payload idempotent, while manual events (no external_id) are
# unaffected because PostgreSQL treats NULLs as distinct.
class ShipmentTrackingEvent < ApplicationRecord
  belongs_to :wine_package

  validates :status, presence: true

  scope :chronological, -> { order(:event_at, :id) }

  # Upserts one normalised provider event. Accepts either symbol or string
  # keys and stores the untouched payload in `raw_data` for debugging/replay.
  def self.record_from_provider!(wine_package, payload)
    data = (payload || {}).to_h.with_indifferent_access
    raw = data.delete(:raw_data)

    external_id = data[:external_id].presence
    event =
      if external_id
        find_or_initialize_by(wine_package: wine_package, external_id: external_id)
      else
        new(wine_package: wine_package)
      end

    event.assign_attributes(
      status: data[:status].presence || "unknown",
      event_at: data[:event_at],
      location: data[:location],
      message: data[:message],
      external_id: external_id,
      raw_data: raw.presence || data.to_h
    )
    event.save!
    event
  end
end
