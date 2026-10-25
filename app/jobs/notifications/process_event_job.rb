# Processes one NotificationEvent: resolves followers and inserts deliveries.
#
# Retry-safe: DeliveryService is idempotent (ON CONFLICT DO NOTHING on the
# (recipient, event) unique index), so a retry after a partial failure never
# duplicates a notification. A deleted/unpublished subject is skipped (the
# event is still marked processed — there is nothing to notify about).
class Notifications::ProcessEventJob < ApplicationJob
  queue_as :notifications

  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  discard_on ActiveJob::DeserializationError

  def perform(event_id)
    event = NotificationEvent.find_by(id: event_id)
    return if event.nil? # event row never committed or was destroyed
    return if event.processed?

    event.mark_processing!
    Notifications::DeliveryService.new(event).deliver
    event.mark_processed!
  rescue StandardError => e
    event&.mark_failed!(e)
    raise # let Active Job's retry policy re-run the job
  end
end