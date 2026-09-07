class BillingEvent < ApplicationRecord
  # Record of processed billing webhook events, enabling idempotent handling.
  # A unique (provider, provider_event_id) constraint guarantees a provider
  # event can only be processed once; processed_at flips when handled.
  PROVIDERS = %w[stripe].freeze

  validates :provider, inclusion: { in: PROVIDERS }
  validates :provider_event_id, presence: true, uniqueness: { scope: :provider }

  scope :processed, -> { where.not(processed_at: nil) }
  scope :pending,   -> { where(processed_at: nil) }

  # Find-or-create an event record and mark it processed atomically. Returns
  # nil if the event was already processed (idempotency guard).
  def self.claim(provider:, provider_event_id:, event_type:, payload: {})
    event = find_or_initialize_by(
      provider: provider,
      provider_event_id: provider_event_id
    )
    return nil if event.persisted? && event.processed_at.present?

    event.update!(
      event_type: event_type,
      payload: payload,
      processed_at: Time.current
    )
    event
  end
end