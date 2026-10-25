require "rails_helper"

# Phase 8 specs (issue #192): per-user notification preferences, the master
# feature flag, and the daily/weekly digest email.
RSpec.describe "Notification preferences and digests", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { User.create!(first_name: "Pref User", email: "pref-user@example.com", password: "password123") }

  before { sign_in user }

  describe "GET /api/v1/account/notification_preferences" do
    it "returns the defaults when no row exists yet" do
      get "/api/v1/account/notification_preferences"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(
        "follow_in_app" => true,
        "follow_email" => false,
        "digest_cadence" => "none"
      )
      expect(user.reload.notification_preference).to be_present
    end

    it "requires authentication" do
      sign_out user
      get "/api/v1/account/notification_preferences"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/account/notification_preferences" do
    it "updates cadence and channels" do
      patch "/api/v1/account/notification_preferences",
            params: { follow_in_app: false, follow_email: true, digest_cadence: "weekly" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(
        "follow_in_app" => false,
        "follow_email" => true,
        "digest_cadence" => "weekly"
      )
    end

    it "rejects an unknown cadence" do
      patch "/api/v1/account/notification_preferences",
            params: { digest_cadence: "hourly" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      # Reload: the in-memory preference object still holds the rejected value.
      expect(user.notification_preference.reload.digest_cadence).to eq("none")
    end
  end

  describe "the follow_notifications_enabled master switch" do
    let(:actor) { User.create!(first_name: "Flag Actor", email: "flag-actor@example.com", password: "password123").tap { |u| u.roles << Role.find_or_create_by!(name: "Reviewer") } }
    let(:producer) { Producer.create!(name: "Flag Producer") }
    let(:wine) { Wine.create!(name: "Flag Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
    let(:vintage) { Vintage.create!(wine: wine, year: 2022) }

    it "stops event publishing when off and resumes when back on" do
      sign_in actor
      AppSetting.set!("follow_notifications_enabled", false)

      post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
           params: { review: { title: "Flag Review", comment: "Note", score: 90,
                               status: "published", source: "manual" } }, as: :json
      expect(response).to have_http_status(:created)
      expect(NotificationEvent.count).to eq(0)

      # Re-enable: the next publication flows through again.
      AppSetting.set!("follow_notifications_enabled", true)
      review = Review.find_by!(title: "Flag Review")
      review.update!(status: "draft")
      patch "/api/v1/reviews/#{review.slug}",
            params: { review: { status: "published" } }, as: :json
      expect(response).to have_http_status(:ok)

      expect(NotificationEvent.where(event_type: "review.published").count).to eq(1)
    ensure
      AppSetting.set!("follow_notifications_enabled", true)
    end
  end

  describe Notifications::DigestJob do
    let(:follower) { User.create!(first_name: "Digest Follower", email: "digest-follower@example.com", password: "password123") }
    let(:actor) { User.create!(first_name: "Digest Actor", email: "digest-actor@example.com", password: "password123").tap { |u| u.roles << Role.find_or_create_by!(name: "Reviewer") } }
    let(:producer) { Producer.create!(name: "Digest Producer") }
    let(:wine) { Wine.create!(name: "Digest Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
    let(:vintage) { Vintage.create!(wine: wine, year: 2021) }
    let!(:review) { Review.create!(vintage: vintage, user: actor, title: "Digest Review", comment: "Note", score: 90, status: "published", source: "manual") }

    def deliver_to(follow_user, cadence)
      # The actor needs the Reviewer role to publish reviews through the API;
      # sign them in (the outer suite has `user` signed in by default).
      sign_in actor
      Follow.create!(user: follow_user, followable: wine)
      NotificationPreference.for(follow_user).update!(digest_cadence: cadence)

      post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
           params: { review: { title: "Digest Review 2", comment: "Second", score: 91,
                               status: "published", source: "manual" } }, as: :json
      expect(response).to have_http_status(:created)
      NotificationEvent.pending.find_each do |event|
        Notifications::ProcessEventJob.perform_now(event.id)
      end
    end

    it "emails daily-cadence users a grouped digest and stamps rows sent" do
      deliver_to(follower, "daily")

      expect { Notifications::DigestJob.perform_now("daily") }
        .to change { ActionMailer::Base.deliveries.count }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([follower.email])
      expect(mail.subject).to include("activity digest")
      expect(mail.body.encoded).to include("Digest Review 2")

      # Idempotent: every follow row is stamped sent; re-running sends nothing.
      expect(follower.notifications.undelivered.count).to eq(0)
      expect { Notifications::DigestJob.perform_now("daily") }
        .not_to change { ActionMailer::Base.deliveries.count }
    end

    it "records failed deliveries and clears them after a successful retry" do
      deliver_to(follower, "daily")
      notifications = follower.notifications.undelivered.to_a
      allow(NotificationPreferencesMailer).to receive(:follow_digest)
        .and_raise(StandardError, "provider unavailable")

      Notifications::DigestJob.perform_now("daily")

      expect(Notification.where(id: notifications.map(&:id), failed_at: nil)).to be_empty
      expect(Notification.where(id: notifications.map(&:id)).pluck(:sent_at)).to all(be_nil)

      allow(NotificationPreferencesMailer).to receive(:follow_digest).and_call_original
      Notifications::DigestJob.perform_now("daily")

      expect(Notification.where(id: notifications.map(&:id), sent_at: nil)).to be_empty
      expect(Notification.where(id: notifications.map(&:id)).pluck(:failed_at)).to all(be_nil)
    end

    it "leaves weekly-cadence rows for the weekly run" do
      deliver_to(follower, "weekly")

      expect { Notifications::DigestJob.perform_now("daily") }
        .not_to change { ActionMailer::Base.deliveries.count }

      expect { Notifications::DigestJob.perform_now("weekly") }
        .to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "never emails package reminder rows in the digest" do
      deliver_to(follower, "daily")
      Notification.create!(recipient: follower, notification_type: "wine_package_deadline",
                           message: "Deadline", wine_package: nil, sent_at: nil)

      Notifications::DigestJob.perform_now("daily")

      expect(Notification.find_by(notification_type: "wine_package_deadline").sent_at).to be_nil
    end

    it "skips users with no pending follow notifications" do
      deliver_to(follower, "daily")
      Notifications::DigestJob.perform_now("daily")
      delivered_count = ActionMailer::Base.deliveries.count

      Notifications::DigestJob.perform_now("daily")

      expect(ActionMailer::Base.deliveries.count).to eq(delivered_count)
    end
  end
end