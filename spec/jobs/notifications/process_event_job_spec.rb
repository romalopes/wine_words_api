require "rails_helper"

# Specs for Notifications::ProcessEventJob and the end-to-end flow
# (publish a review through the API -> followers get an in-app notification).
RSpec.describe Notifications::ProcessEventJob, type: :job do
  let(:actor) { User.create!(first_name: "Job Actor", email: "job-actor@example.com", password: "password123") }
  let(:follower) { User.create!(first_name: "Job Follower", email: "job-follower@example.com", password: "password123") }
  let(:producer) { Producer.create!(name: "Job Producer") }
  let(:wine) { Wine.create!(name: "Job Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:review) { Review.create!(vintage: vintage, user: actor, title: "Job Review", comment: "Note", score: 90, status: "published", source: "manual") }

  def publish_event
    Notifications::EventPublisher.publish!(event_type: "review.published", subject: review, actor: actor)
  end

  describe "#perform" do
    it "delivers to followers and marks the event processed" do
      Follow.create!(user: follower, followable: review)
      event = publish_event

      described_class.perform_now(event.id)

      expect(event.reload).to be_processed
      expect(Notification.where(recipient: follower, notification_event: event)).to exist
    end

    it "marks deliveries as unread" do
      Follow.create!(user: follower, followable: review)
      event = publish_event

      described_class.perform_now(event.id)

      expect(Notification.where(recipient: follower).last.read_at).to be_nil
    end

    it "skips events that no longer exist (row never committed)" do
      expect { described_class.perform_now(999_999) }.not_to raise_error
    end

    it "does not reprocess an already-processed event" do
      Follow.create!(user: follower, followable: review)
      event = publish_event
      described_class.perform_now(event.id)

      expect { described_class.perform_now(event.id) }
        .not_to change { Notification.count }
    end

    it "records the failure so Active Job retries (retry_on swallows the error)" do
      event = publish_event
      allow(Notifications::DeliveryService).to receive(:new).and_raise(StandardError.new("boom"))
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      described_class.perform_now(event.id)

      expect(event.reload).to be_failed
      expect(event.last_error).to include("boom")
      expect(described_class).to have_been_enqueued.with(event.id)
    end

    it "skips delivery when the subject was deleted before processing" do
      Follow.create!(user: follower, followable: review)
      event = publish_event
      review.destroy

      expect { described_class.perform_now(event.id) }.not_to raise_error
      expect(event.reload).to be_processed
      expect(Notification.count).to eq(0)
    end
  end

  describe Notifications::RecoveryJob, "#perform" do
    before { ActiveJob::Base.queue_adapter.enqueued_jobs.clear }

    it "re-enqueues stale pending events and returns the count" do
      event = publish_event
      event.update_columns(processing_started_at: 2.hours.ago)
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      recovered = described_class.perform_now

      expect(recovered).to eq(1)
      expect(Notifications::ProcessEventJob).to have_been_enqueued.with(event.id).exactly(:once)
    end

    it "leaves fresh pending events alone" do
      publish_event
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      expect(described_class.perform_now).to eq(0)
      expect(Notifications::ProcessEventJob).not_to have_been_enqueued
    end
  end
end