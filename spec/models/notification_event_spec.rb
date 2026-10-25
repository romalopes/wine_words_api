require "rails_helper"

# Unit specs for NotificationEvent — the follow-notification outbox
# (issue #192). The important contract is idempotency: a published event's
# idempotency_key is unique, so repeating a publish callback never creates a
# second event, and state transitions track pending -> processed/failed.
RSpec.describe NotificationEvent, type: :model do
  let(:actor) { User.create!(first_name: "Event Actor", email: "event-actor@example.com", password: "password123") }
  let(:producer) { Producer.create!(name: "Event Producer") }
  let(:wine) { Wine.create!(name: "Event Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:review) { Review.create!(vintage: vintage, user: actor, title: "Event Review", comment: "Note", score: 90, status: "published", source: "manual") }

  def build_event(attrs = {})
    described_class.new({
      event_type: "review.published",
      subject_type: "Review",
      subject_id: review.id,
      actor_id: actor.id,
      occurred_at: Time.current,
      affected_targets: [{ "type" => "Review", "id" => review.id }],
      metadata: { subject_label: review.title, subject_slug: review.slug },
      idempotency_key: "review.published.Review.#{review.id}"
    }.merge(attrs))
  end

  describe "validations" do
    it "requires a known event type" do
      event = build_event(event_type: "bogus")
      expect(event).not_to be_valid
      expect(event.errors[:event_type]).to be_present
    end

    it "requires an idempotency key" do
      event = build_event(idempotency_key: nil)
      expect(event).not_to be_valid
    end

    it "rejects a duplicate idempotency key" do
      build_event.save!
      duplicate = build_event
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:idempotency_key]).to be_present
    end

    it "accepts a valid event" do
      expect(build_event).to be_valid
    end
  end

  describe "state transitions" do
    it "starts pending" do
      event = build_event.tap(&:save!)
      expect(event).to be_pending
      expect(event).not_to be_processed
      expect(event).not_to be_failed
    end

    it "marks processing and counts attempts" do
      event = build_event.tap(&:save!)
      event.mark_processing!
      expect(event.processing_started_at).to be_present
      expect(event.attempts).to eq(1)
    end

    it "marks processed" do
      event = build_event.tap(&:save!)
      event.mark_processing!
      event.mark_processed!
      expect(event).to be_processed
      expect(event).not_to be_pending
      expect(event).not_to be_failed
    end

    it "records the failure reason" do
      event = build_event.tap(&:save!)
      error = StandardError.new("boom")
      event.mark_failed!(error)
      expect(event).to be_failed
      expect(event.last_error).to eq("StandardError: boom")
    end
  end

  describe "#targets" do
    it "normalizes the affected_targets snapshot" do
      event = build_event(
        affected_targets: [
          { "type" => "Review", "id" => review.id },
          { "type" => "Wine", "id" => wine.id }
        ]
      ).tap(&:save!)

      expect(event.targets).to contain_exactly(
        { type: "Review", id: review.id },
        { type: "Wine", id: wine.id }
      )
    end
  end

  describe "scopes" do
    it "separates pending, processed and failed" do
      pending_event = build_event(idempotency_key: "k1").tap(&:save!)
      processed_event = build_event(idempotency_key: "k2").tap(&:save!)
      processed_event.mark_processing!
      processed_event.mark_processed!
      failed_event = build_event(idempotency_key: "k3").tap(&:save!)
      failed_event.mark_failed!(StandardError.new("x"))

      expect(described_class.pending).to contain_exactly(pending_event)
      expect(described_class.processed).to contain_exactly(processed_event)
      expect(described_class.failed).to contain_exactly(failed_event)
    end

    it "stale_pending catches stale in-flight events and old never-started ones" do
      fresh = build_event(idempotency_key: "k1").tap(&:save!)
      stale_running = build_event(
        idempotency_key: "k2",
        processing_started_at: 2.hours.ago
      ).tap(&:save!)
      lost_enqueue = build_event(
        idempotency_key: "k3",
        created_at: 2.hours.ago,
        updated_at: 2.hours.ago
      ).tap(&:save!)

      expect(described_class.stale_pending(1.hour.ago)).to contain_exactly(stale_running, lost_enqueue)
    end
  end

  describe "notifications association" do
    it "survives event deletion (notifications are nullified)" do
      event = build_event.tap(&:save!)
      notification = Notification.create!(
        recipient: actor, notification_type: "review_published",
        message: "m", notification_event: event, delivered_at: Time.current
      )

      event.destroy

      expect(Notification.exists?(notification.id)).to be true
      expect(notification.reload.notification_event_id).to be_nil
    end
  end
end