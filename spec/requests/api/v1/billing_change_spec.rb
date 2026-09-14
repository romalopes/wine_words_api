require "rails_helper"

RSpec.describe "Api::V1::Billing#change", type: :request do
  it "requires authentication for preview" do
    post "/api/v1/billing/change/preview", params: { subscription_id: 1 }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "requires authentication for confirm" do
    post "/api/v1/billing/change/confirm",
         params: { subscription_id: 1, idempotency_key: "k" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end