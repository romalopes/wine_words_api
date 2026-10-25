# Sweeps NotificationEvents that were recorded but never processed — the
# outbox safety net for lost enqueues or worker crashes. Runs daily from
# config/recurring.yml; `stale_pending` covers both never-started events and
# runs whose worker died mid-processing (stale processing_started_at).
class Notifications::RecoveryJob < ApplicationJob
  queue_as :notifications

  STALE_AFTER = 1.hour

  def perform
    events = NotificationEvent.stale_pending(STALE_AFTER.ago).limit(1000)
    events.find_each do |event|
      Rails.logger.warn("[Notifications] recovering stale event #{event.id} (#{event.event_type})")
      Notifications::ProcessEventJob.perform_later(event.id)
    end
    events.size
  end
end