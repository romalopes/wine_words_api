require "rails_helper"
require "devise"

# Issue #185 — API surface for article/review deadlines.
#
# Covers backward compatibility (clients that omit `deadline` keep working),
# explicit overrides, and the existing ownership rules: a deadline is just
# another field on the record, so whoever may edit the record may edit it.
RSpec.describe "Api::V1 deadlines", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveSupport::Testing::TimeHelpers

  around do |example|
    travel_to(Time.zone.local(2026, 10, 21, 10, 0)) { example.run }
  end

  let(:producer) { Producer.create!(name: "API Deadline Producer") }
  let(:wine) { Wine.create!(name: "API Deadline Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2021) }

  let(:manager) do
    user = User.create!(first_name: "API Manager", email: "api-manager@example.com",
                        password: "password123")
    user.roles << Role.find_or_create_by!(name: "Reviewer")
    user
  end
  let(:owner) do
    User.create!(first_name: "API Owner", email: "api-owner@example.com",
                 password: "password123")
  end
  let(:stranger) do
    User.create!(first_name: "API Stranger", email: "api-stranger@example.com",
                 password: "password123")
  end

  describe "articles" do
    it "defaults the deadline when the client omits it (backward compatible)" do
      sign_in manager

      post "/api/v1/articles",
           params: { article: { title: "Legacy client", status: "draft" } }, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["deadline"]).to eq("2026-11-04")
      expect(body["overdue"]).to be(false)
      expect(body["days_until_deadline"]).to eq(14)
    end

    it "persists an explicit deadline" do
      sign_in manager

      post "/api/v1/articles",
           params: { article: { title: "Dated article", status: "draft",
                                deadline: "2026-10-25" } }, as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["deadline"]).to eq("2026-10-25")
      expect(Article.find_by(title: "Dated article").deadline).to eq(Date.new(2026, 10, 25))
    end

    it "lets the owner change the deadline" do
      article = Article.create!(title: "Owned article", status: "draft", user: owner,
                                deadline: Date.new(2026, 10, 25))
      sign_in owner

      patch "/api/v1/articles/#{article.id}",
            params: { article: { deadline: "2026-12-01" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(article.reload.deadline).to eq(Date.new(2026, 12, 1))
    end

    it "forbids an unrelated user from changing the deadline" do
      article = Article.create!(title: "Protected article", status: "draft", user: owner,
                                deadline: Date.new(2026, 10, 25))
      sign_in stranger

      patch "/api/v1/articles/#{article.id}",
            params: { article: { deadline: "2026-12-01" } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(article.reload.deadline).to eq(Date.new(2026, 10, 25))
    end
  end

  describe "reviews" do
    def create_review_payload(attrs = {})
      { review: { score: 88, status: "draft" }.merge(attrs) }
    end

    it "defaults a standalone review and returns the deadline fields" do
      sign_in manager

      post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
           params: create_review_payload, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["deadline"]).to eq("2026-11-04")
      expect(body["overdue"]).to be(false)
      expect(body["days_until_deadline"]).to eq(14)
    end

    it "persists an explicit deadline" do
      sign_in manager

      post "/api/v1/wines/#{wine.slug}/vintages/#{vintage.id}/reviews",
           params: create_review_payload(deadline: "2026-10-22"), as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["deadline"]).to eq("2026-10-22")
    end

    it "lets the owner change the deadline" do
      review = Review.create!(title: "Owned review", score: 80, status: "draft",
                              user: owner, vintage: vintage, deadline: Date.new(2026, 10, 25))
      sign_in owner

      patch "/api/v1/reviews/#{review.id}",
            params: { review: { deadline: "2026-12-01" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(review.reload.deadline).to eq(Date.new(2026, 12, 1))
    end

    it "forbids an unrelated user from changing the deadline" do
      review = Review.create!(title: "Protected review", score: 80, status: "draft",
                              user: owner, vintage: vintage, deadline: Date.new(2026, 10, 25))
      sign_in stranger

      patch "/api/v1/reviews/#{review.id}",
            params: { review: { deadline: "2026-12-01" } }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(review.reload.deadline).to eq(Date.new(2026, 10, 25))
    end
  end
end
