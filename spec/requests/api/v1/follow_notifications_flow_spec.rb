require "rails_helper"

# End-to-end follow-notification flows (issue #192): content operations through
# the API publish events; processing them delivers in-app notifications to
# followers with dedup, actor exclusion and privacy rules.
RSpec.describe "Follow notification flows", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:actor) { User.create!(first_name: "E2E Actor", email: "e2e-actor@example.com", password: "password123").tap { |u| u.roles << Role.find_or_create_by!(name: "Reviewer") } }
  let(:follower) { User.create!(first_name: "E2E Follower", email: "e2e-follower@example.com", password: "password123") }
  let(:producer) { Producer.create!(name: "E2E Producer") }
  let(:wine) { Wine.create!(name: "E2E Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }

  before { sign_in actor }

  def process_events!
    NotificationEvent.pending.find_each do |event|
      Notifications::ProcessEventJob.perform_now(event.id)
    end
  end

  it "notifies a wine follower exactly once when a review is published" do
    Follow.create!(user: follower, followable: wine)

    post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
         params: { review: { title: "E2E Review", comment: "Lovely", score: 91,
                             status: "published", source: "manual" } }, as: :json
    expect(response).to have_http_status(:created)
    process_events!

    notifications = Notification.where(recipient: follower).to_a
    expect(notifications.length).to eq(1) # dedup across Review/Wine/Producer targets
    expect(notifications.first.message).to eq("Review published: E2E Review")
    expect(notifications.first.notification_type).to eq("review_published")
    expect(notifications.first.delivered_at).to be_present
    expect(notifications.first.read_at).to be_nil
  end

  it "never notifies the actor" do
    Follow.create!(user: actor, followable: wine)

    post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
         params: { review: { title: "Own Review", comment: "Mine", score: 88,
                             status: "published", source: "manual" } }, as: :json
    process_events!

    expect(Notification.where(recipient: actor)).not_to exist
  end

  it "does not publish events for draft edits" do
    post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
         params: { review: { title: "Draft Review", comment: "Draft", score: 70,
                             status: "draft", source: "manual" } }, as: :json

    expect(response).to have_http_status(:created)
    expect(NotificationEvent.count).to eq(0)
  end

  it "does not publish events for deadline-only updates" do
    review = Review.create!(vintage: vintage, user: actor, title: "E2E Deadline",
                            comment: "Note", score: 90, status: "published", source: "manual")

    patch "/api/v1/reviews/#{review.slug}",
          params: { review: { deadline: Date.current + 3 } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(NotificationEvent.count).to eq(0)
  end

  it "publishes review.updated for meaningful edits of a published review" do
    review = Review.create!(vintage: vintage, user: actor, title: "E2E Update",
                            comment: "Note", score: 90, status: "published", source: "manual")

    patch "/api/v1/reviews/#{review.slug}",
          params: { review: { comment: "Rewritten tasting note" } }, as: :json

    expect(NotificationEvent.where(event_type: "review.updated").count).to eq(1)
  end

  it "notifies producer followers when a wine is created" do
    Follow.create!(user: follower, followable: producer)

    post "/api/v1/wines",
         params: { wine: { name: "E2E New Wine", producer_id: producer.id, color: "White",
                           closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 } }, as: :json
    expect(response).to have_http_status(:created)
    process_events!

    notifications = Notification.where(recipient: follower).to_a
    expect(notifications.length).to eq(1)
    expect(notifications.first.notification_type).to eq("wine_created")
    expect(notifications.first.message).to eq("Wine created: E2E New Wine")
  end

  it "does not publish comment events for wine comments (issue #192 scope)" do
    post "/api/v1/wines/#{wine.slug}/comments",
         params: { comment: { body: "Nice bottle" } }, as: :json

    expect(NotificationEvent.count).to eq(0)
  end

  it "delivered follow notifications appear in the notifications feed with target links" do
    Follow.create!(user: follower, followable: wine)
    post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
         params: { review: { title: "Feed Review", comment: "Yum", score: 92,
                             status: "published", source: "manual" } }, as: :json
    process_events!

    sign_in follower
    get "/api/v1/notifications"

    body = JSON.parse(response.body)
    follow_item = body.find { |n| n["notification_event_id"].present? }
    expect(follow_item).to include(
      "notification_type" => "review_published",
      "target_path" => "/reviews/#{Review.find_by(title: "Feed Review").slug}",
      "target_label" => "Feed Review"
    )
    expect(follow_item["sent"]).to be false
    expect(follow_item["read"]).to be false
  end
end