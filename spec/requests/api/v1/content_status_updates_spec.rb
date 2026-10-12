require "rails_helper"

RSpec.describe "Content status updates", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    User.create!(first_name: "Admin", email: "status-admin@example.com", password: "password123").tap do |user|
      user.roles << Role.find_or_create_by!(name: "Admin")
    end
  end
  let(:article) { Article.create!(title: "Status article", user: admin, status: "draft") }
  let(:review) do
    producer = Producer.create!(name: "Status Estate")
    wine = Wine.create!(name: "Status Wine", color: "Red", producer: producer)
    vintage = Vintage.create!(wine: wine, year: 2020)
    Review.create!(title: "Status review", user: admin, vintage: vintage, score: 90, status: "draft")
  end

  %w[article review].each do |kind|
    it "publishes a #{kind} without serializing its associations" do
      record = public_send(kind)
      sign_in admin
      expect("#{kind.capitalize}Serializer".constantize).not_to receive(:new)
      queries = []
      callback = ->(*args) { queries << args.last[:sql] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        patch "/api/v1/#{kind}s/#{record.slug}",
          params: { kind => { status: "published", published_at: "2026-10-13T00:00:00Z" } },
          headers: { "Prefer" => "return=minimal" }, as: :json
      end
      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(record.reload.status).to eq("published")
      expect(record.published_at).to eq(Time.iso8601("2026-10-13T00:00:00Z"))
      expect(queries.grep(/to_tsvector/)).to be_empty
    end

    it "still validates a #{kind} status when a minimal response is requested" do
      record = public_send(kind)
      sign_in admin
      patch "/api/v1/#{kind}s/#{record.slug}", params: { kind => { status: "invalid" } },
        headers: { "Prefer" => "return=minimal" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(record.reload.status).to eq("draft")
    end
  end
end
