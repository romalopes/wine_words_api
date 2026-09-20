# Private test-access gate: request-level behaviour of the TestAccess concern
# and the Api::V1::TestAccessController endpoints.
require "rails_helper"

RSpec.describe "Api::V1::TestAccess", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "wine-gate-password-123" }

  before do
    ENV["TEST_ACCESS_PASSWORD"] = password
    ENV.delete("TEST_ACCESS_TOKEN_EXPIRATION")
  end

  after do
    ENV.delete("TEST_ACCESS_PASSWORD")
    ENV.delete("TEST_ACCESS_TOKEN_EXPIRATION")
  end

  describe "POST /api/v1/test_access" do
    it "rejects a wrong password with 401 and no hint" do
      post "/api/v1/test_access", params: { password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["authenticated"]).to be(false)
      expect(body["error"]).to eq("Invalid password")
      expect(body["token"]).to be_nil
    end

    it "returns a signed token and expiry for the correct password" do
      post "/api/v1/test_access", params: { password: password }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["authenticated"]).to be(true)
      expect(TestAccessToken.valid?(body["token"])).to be(true)
      expect(body["expires_at"]).to be_present
      expect(Time.iso8601(body["expires_at"])).to be_within(5.seconds).of(7.days.from_now)
    end

    it "reports the disabled state when no password is configured" do
      ENV.delete("TEST_ACCESS_PASSWORD")

      post "/api/v1/test_access", params: { password: "anything" }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["authenticated"]).to be(true)
      expect(body["disabled"]).to be(true)
      expect(body["token"]).to be_nil
    end
  end

  describe "GET /api/v1/test_access" do
    it "accepts a valid token" do
      get "/api/v1/test_access",
          headers: { "X-Test-Access-Token" => TestAccessToken.generate }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["authenticated"]).to be(true)
    end

    it "rejects an invalid token" do
      get "/api/v1/test_access",
          headers: { "X-Test-Access-Token" => "garbage" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "the gate on protected API endpoints" do
    # GET /api/v1/articles is public in the ordinary Devise sense (browse
    # without a User), which makes it a clean probe for the test-access layer.
    it "rejects requests without the test-access header" do
      get "/api/v1/articles", as: :json

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body["code"]).to eq("test_access_required")
    end

    it "accepts requests with a valid test-access token" do
      get "/api/v1/articles",
          headers: { "X-Test-Access-Token" => TestAccessToken.generate }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "rejects a tampered token" do
      token = TestAccessToken.generate
      get "/api/v1/articles",
          headers: { "X-Test-Access-Token" => "#{token}x" }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects an expired token" do
      ENV["TEST_ACCESS_TOKEN_EXPIRATION"] = "1.hour"
      token = TestAccessToken.generate

      travel 2.hours do
        get "/api/v1/articles",
            headers: { "X-Test-Access-Token" => token }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "when the gate is disabled" do
    it "leaves protected endpoints open without any token" do
      ENV.delete("TEST_ACCESS_PASSWORD")

      get "/api/v1/articles", as: :json

      expect(response).to have_http_status(:ok)
    end

    it "reports success on verification so a deployed SPA stays unlocked" do
      ENV.delete("TEST_ACCESS_PASSWORD")

      get "/api/v1/test_access", as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["authenticated"]).to be(true)
      expect(body["disabled"]).to be(true)
    end
  end

  describe "health endpoints" do
    it "keeps the liveness probe public" do
      get "/api/v1/health"

      expect(response).to have_http_status(:ok)
    end

    it "gates the detailed diagnostics behind the test-access layer" do
      get "/api/v1/health/detailed"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
