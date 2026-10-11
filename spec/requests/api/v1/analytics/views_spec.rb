require "rails_helper"

RSpec.describe "POST /api/v1/analytics/views", type: :request do
  include Devise::Test::IntegrationHelpers

  def create_user(email_prefix)
    User.create!(first_name: "Analytics #{email_prefix} #{SecureRandom.hex(2)}",
                 email: "analytics-#{email_prefix}-#{SecureRandom.hex(4)}@example.com",
                 password: "password123")
  end

  let(:user) { create_user("owner") }
  let(:article) { Article.create!(title: "Analytics Article #{SecureRandom.hex(3)}", user: user, status: "published") }
  let(:visitor_id) { "550e8400-e29b-41d4-a716-446655440000" }

  def valid_payload(overrides = {})
    {
      event_type: "view",
      content_type: "Article",
      content_id: article.id,
      occurred_at: Time.current.iso8601,
      source: "direct"
    }.merge(overrides)
  end

  context "anonymous with X-Visitor-ID" do
    let(:headers) { { "X-Visitor-ID" => visitor_id } }

    it "returns 202 with accepted true" do
      perform_enqueued_jobs do
        post "/api/v1/analytics/views", params: valid_payload, headers: headers, as: :json
      end
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["accepted"]).to be true
    end

    it "creates an accepted event with visitor identity" do
      expect {
        perform_enqueued_jobs do
          post "/api/v1/analytics/views", params: valid_payload, headers: headers, as: :json
        end
      }.to change { Analytics::Event.accepted.count }.by(1)
      event = Analytics::Event.last
      expect(event.identity).to eq("visitor:#{visitor_id}")
      expect(event.viewable_type).to eq("Article")
    end

    it "deduplicates a second view within the window" do
      perform_enqueued_jobs do
        post "/api/v1/analytics/views", params: valid_payload, headers: headers, as: :json
        post "/api/v1/analytics/views", params: valid_payload, headers: headers, as: :json
      end
      expect(Analytics::Event.accepted.for_content("Article", article.id).count).to eq(1)
    end
  end

  context "anonymous without X-Visitor-ID" do
    it "generates a visitor identity and returns 202" do
      perform_enqueued_jobs do
        post "/api/v1/analytics/views", params: valid_payload, as: :json
      end
      expect(response).to have_http_status(:accepted)
      expect(Analytics::Event.last.identity).to match(/\Avisitor:[0-9a-f-]{36}\z/)
    end
  end

  context "invalid payload" do
    it "rejects unknown content_type with 422" do
      post "/api/v1/analytics/views",
           params: valid_payload(content_type: "User"),
           headers: { "X-Visitor-ID" => visitor_id }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("Invalid content_type")
    end

    it "rejects missing content_id with 422" do
      payload = valid_payload.except(:content_id)
      post "/api/v1/analytics/views",
           params: payload,
           headers: { "X-Visitor-ID" => visitor_id }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects invalid event_type with 422" do
      post "/api/v1/analytics/views",
           params: valid_payload(event_type: "click"),
           headers: { "X-Visitor-ID" => visitor_id }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to eq("Invalid event_type")
    end

    it "rejects malformed visitor ID with 422" do
      post "/api/v1/analytics/views",
           params: valid_payload,
           headers: { "X-Visitor-ID" => "not-a-uuid" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context "authenticated" do
    let(:viewer) { create_user("viewer") }
    before { sign_in viewer }

    it "uses account identity" do
      expect {
        perform_enqueued_jobs do
          post "/api/v1/analytics/views", params: valid_payload, as: :json
        end
      }.to change { Analytics::Event.accepted.count }.by(1)
      expect(Analytics::Event.last.identity).to eq("account:#{viewer.id}")
    end

    it "returns 202 for opted-out user without creating an event" do
      viewer.update!(analytics_opt_out: true)
      expect {
        perform_enqueued_jobs do
          post "/api/v1/analytics/views", params: valid_payload, as: :json
        end
      }.not_to change { Analytics::Event.accepted.count }
      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body["accepted"]).to be true
    end

    it "returns 202 without counting when author views own article" do
      sign_in user
      expect {
        perform_enqueued_jobs do
          post "/api/v1/analytics/views", params: valid_payload, as: :json
        end
      }.not_to change { Analytics::Event.accepted.count }
      expect(response).to have_http_status(:accepted)
    end

    it "returns 202 for inaccessible content without counting" do
      draft = Article.create!(title: "Draft #{SecureRandom.hex(3)}", user: create_user("other"), status: "draft")
      expect {
        perform_enqueued_jobs do
          post "/api/v1/analytics/views", params: valid_payload(content_id: draft.id), as: :json
        end
      }.not_to change { Analytics::Event.accepted.count }
      expect(response).to have_http_status(:accepted)
    end
  end

  context "invalid JWT" do
    it "returns 401 instead of anonymous fallback" do
      post "/api/v1/analytics/views",
           params: valid_payload,
           headers: { "Authorization" => "Bearer invalid.token.here" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "CORS" do
    it "allows the configured frontend origin" do
      post "/api/v1/analytics/views",
           params: valid_payload,
           headers: { "Origin" => "http://localhost:5173", "X-Visitor-ID" => visitor_id }, as: :json
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:5173")
    end
  end
end
