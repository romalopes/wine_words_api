# Carrier-independent tracking aggregate, one per wine package.
#
# The row is a thin, replaceable record of "what the carrier says right now".
# How that data is obtained is answered by `TrackingProvider` (Phase C):
#   * "manual"         — a reviewer types the status in;
#   * "australia_post" — the Australia Post API, only when credentials exist.
#
# IMPORTANT: `delivered_at` is informational. It must never automatically mark
# the package as arrived — a reviewer always confirms physical arrival.
class ShipmentTracking < ApplicationRecord
  belongs_to :wine_package
  has_many :shipment_tracking_events, through: :wine_package

  # "manual" | "australia_post" | ... (validated by the provider registry).
  PROVIDER_MANUAL = "manual".freeze

  validates :provider, presence: true

  scope :delivered, -> { where.not(delivered_at: nil) }

  # Keeps the package's denormalized tracking snapshot (tracking_carrier,
  # tracking_number, tracking_url, tracking_status, delivered_at, ...) in step
  # so the current shipping state is cheap to read on the package itself.
  # Written with update_columns on purpose: this is a data projection, not a
  # workflow change, so package validations/callbacks must not run.
  after_save :sync_wine_package_tracking_columns

  # Carrier "Australia Post" implies the Australia Post provider unless a
  # different non-manual provider was configured explicitly, so a caller only
  # has to set the carrier. `provider` is NOT NULL with a "manual" default, so
  # this can only ever *upgrade* the default.
  before_validation :infer_provider_from_carrier

  # The provider implementation responsible for this row.
  def provider_impl
    TrackingProvider.for(provider)
  end

  def delivered?
    delivered_at.present?
  end

  # Re-resolves the shipment through the provider and records what came back.
  # Never touches the package's status/arrived_at — see the class comment.
  def refresh!(at: Time.current)
    apply_result!(provider_impl.track(number), at: at)
    self
  end

  # Applies a normalised provider result:
  #   { status:, url:, status_updated_at:, estimated_delivery_at:, delivered_at:,
  #     events: [...] }
  #
  # Only the keys the provider actually returned are applied, so a provider
  # that yields nothing (manual entry, an unreachable carrier API) never wipes
  # data a reviewer already recorded.
  def apply_result!(result, at: Time.current)
    result = (result || {}).with_indifferent_access

    attributes = { status_updated_at: result[:status_updated_at] || at }
    attributes[:status] = result[:status] if result[:status].present?
    attributes[:url] = result[:url] if result[:url].present?
    attributes[:estimated_delivery_at] = result[:estimated_delivery_at] if result.key?(:estimated_delivery_at)
    attributes[:delivered_at] = result[:delivered_at] if result.key?(:delivered_at)

    update!(attributes)

    Array(result[:events]).each do |event|
      ShipmentTrackingEvent.record_from_provider!(wine_package, event)
    end

    self
  end

  private

  def infer_provider_from_carrier
    return if carrier.blank?

    inferred = TrackingProvider.key_for(carrier)
    return if inferred == TrackingProvider::MANUAL

    self.provider = inferred if provider.blank? || provider == TrackingProvider::MANUAL
  end

  def sync_wine_package_tracking_columns
    return if wine_package.nil?

    wine_package.update_columns(
      tracking_carrier: carrier,
      tracking_number: number,
      tracking_url: url,
      tracking_status: status,
      tracking_status_updated_at: status_updated_at,
      estimated_delivery_at: estimated_delivery_at,
      delivered_at: delivered_at,
      updated_at: Time.current
    )
  end
end
