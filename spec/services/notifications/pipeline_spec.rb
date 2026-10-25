require "rails_helper"

# Specs for the notification-event pipeline services (issue #192):
# target resolution (Review -> Vintage -> Wine -> Producer inheritance),
# event publishing idempotency, follower eligibility and delivery dedup.
RSpec.describe Notifications, type: :service do
  let(:actor) { User.create!(first_name: "Pipeline Actor", email: "pipeline-actor@example.com", password: "password123") }
  let(:follower) { User.create!(first_name: "Pipeline Follower", email: "pipeline-follower@example.com", password: "password123") }
  let(:other_follower) { User.create!(first_name: "Pipeline Other", email: "pipeline-other@example.com", password: "password123") }
  let(:producer) { Producer.create!(name: "Pipeline Producer") }
  let(:wine) { Wine.create!(name: "Pipeline Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:review) { Review.create!(vintage: vintage, user: actor, title: "Pipeline Review", comment: "Note", score: 90, status: "published", source: "manual") }
  let(:article) do
    article = Article.create!(user: actor, title: "Pipeline Article", abstract: "Abstract", body: "Body", status: "published", source: "manual")
    article.article_vintages.create!(vintage: vintage)
    article.article_producers.create!(producer: producer)
    article
  end

  describe Notifications::AffectedTargetsResolver do
    def targets(subject)
      described_class.new(subject).resolve.map { |t| [t["type"], t["id"]] }
    end

    it "propagates a review to its wine and producer" do
      expect(targets(review)).to contain_exactly(
        ["Review", review.id], ["Wine", wine.id], ["Producer", producer.id]
      )
    end

    it "propagates an article to linked wines and direct + inherited producers" do
      expect(targets(article)).to contain_exactly(
        ["Article", article.id], ["Wine", wine.id], ["Producer", producer.id]
      )
    end

    it "propagates a wine to itself and its producer" do
      expect(targets(wine)).to contain_exactly(
        ["Wine", wine.id], ["Producer", producer.id]
      )
    end

    it "propagates a vintage to its wine and producer" do
      expect(targets(vintage)).to contain_exactly(
        ["Wine", wine.id], ["Producer", producer.id]
      )
    end

    it "propagates a producer to itself" do
      expect(targets(producer)).to contain_exactly(["Producer", producer.id])
    end

    it "rejects an unknown subject" do
      expect { targets(actor) }.to raise_error(ArgumentError)
    end
  end

  describe Notifications::EventPublisher do
    it "creates an event with the affected-targets snapshot" do
      event = described_class.publish!(event_type: "review.published", subject: review, actor: actor)

      expect(event).to be_pending
      expect(event.targets).to contain_exactly(
        { type: "Review", id: review.id },
        { type: "Wine", id: wine.id },
        { type: "Producer", id: producer.id }
      )
      expect(event.metadata["subject_label"]).to eq("Pipeline Review")
    end

    it "enqueues processing for the created event" do
      expect do
        described_class.publish!(event_type: "review.published", subject: review, actor: actor)
      end.to have_enqueued_job(Notifications::ProcessEventJob)
    end

    it "is idempotent for deterministic events (published / comment / created)" do
      first = described_class.publish!(event_type: "review.published", subject: review, actor: actor)
      second = described_class.publish!(event_type: "review.published", subject: review, actor: actor)

      expect(second.id).to eq(first.id)
      expect(NotificationEvent.count).to eq(1)
    end

    it "creates a new event for every meaningful update" do
      first = described_class.publish!(event_type: "review.updated", subject: review, actor: actor)
      second = described_class.publish!(event_type: "review.updated", subject: review, actor: actor)

      expect(second.id).not_to eq(first.id)
      expect(NotificationEvent.count).to eq(2)
    end

    it "comments are their own event per comment id" do
      key = "review.comment_created.Review.#{review.id}.comment.42"
      first = described_class.publish!(event_type: "review.comment_created", subject: review, actor: actor, idempotency_key: key)
      second = described_class.publish!(event_type: "review.comment_created", subject: review, actor: actor, idempotency_key: key)

      expect(second.id).to eq(first.id)
    end
  end

  describe Notifications::FollowerResolver do
    def publish_event
      Notifications::EventPublisher.publish!(
        event_type: "review.published", subject: review, actor: actor
      )
    end

    def resolver_for(event)
      Notifications::FollowerResolver.new(event)
    end

    it "returns distinct users following any target, actor excluded" do
      Follow.create!(user: follower, followable: review)
      Follow.create!(user: follower, followable: wine) # inherited coverage: same event
      Follow.create!(user: other_follower, followable: producer)

      recipients = resolver_for(publish_event).resolve

      expect(recipients.sort).to eq([follower.id, other_follower.id].sort)
      expect(recipients).not_to include(actor.id)
    end

    it "excludes the actor even when they follow the target" do
      Follow.create!(user: actor, followable: review)

      expect(resolver_for(publish_event).resolve).to eq([])
    end

    it "ignores follows created after the event occurred" do
      event = publish_event
      late = Follow.create!(user: follower, followable: review)
      Follow.where(id: late.id).update_all(created_at: 1.hour.from_now)

      expect(resolver_for(event).resolve).to eq([])
    end

    it "includes a user following only one of several targets" do
      Follow.create!(user: other_follower, followable: producer)

      expect(resolver_for(publish_event).resolve).to eq([other_follower.id])
    end
  end

  describe Notifications::DeliveryService do
    let(:event) do
      Notifications::EventPublisher.publish!(
        event_type: "review.published", subject: review, actor: actor
      )
    end

    it "inserts one delivered notification per follower" do
      Follow.create!(user: follower, followable: review)
      Follow.create!(user: other_follower, followable: producer)

      expect { described_class.new(event).deliver }
        .to change { Notification.where(notification_event: event).count }.by(2)

      row = Notification.find_by(recipient: follower, notification_event: event)
      expect(row.delivered_at).to be_present
      expect(row.sent_at).to be_nil
      expect(row.notification_type).to eq("review_published")
      expect(row.message).to eq("Review published: Pipeline Review")
      expect(row.target_path).to eq("/reviews/#{review.slug}")
      expect(row.target_label).to eq("Pipeline Review")
      expect(row.actor_id).to eq(actor.id)
    end

    it "is idempotent: reprocessing never duplicates" do
      Follow.create!(user: follower, followable: review)
      described_class.new(event).deliver

      expect { described_class.new(event).deliver }
        .not_to change { Notification.where(notification_event: event).count }
    end

    it "skips delivery when the subject is no longer publicly visible" do
      Follow.create!(user: follower, followable: review)
      review.update!(status: "draft")

      expect(described_class.new(event).deliver).to eq(0)
      expect(Notification.where(recipient: follower).count).to eq(0)
    end

    it "does not deliver to followers of unrelated targets" do
      other_producer = Producer.create!(name: "Unrelated Producer")
      Follow.create!(user: follower, followable: other_producer)

      expect(described_class.new(event).deliver).to eq(0)
      expect(Notification.count).to eq(0)
    end
  end

  describe Notifications::Visibility do
    it "hides draft and archived reviews/articles" do
      expect(Notifications::Visibility.visible?(review)).to be true
      review.update!(status: "draft")
      expect(Notifications::Visibility.visible?(review.reload)).to be false
    end

    it "treats wines and producers as always visible" do
      expect(Notifications::Visibility.visible?(wine)).to be true
      expect(Notifications::Visibility.visible?(producer)).to be true
      expect(Notifications::Visibility.visible?(nil)).to be false
    end
  end
end