require "rails_helper"

RSpec.describe "Api::V1::Trade::Pricing", type: :request do
  describe "GET /api/v1/trade/pricing" do
    it "returns the default fee without authentication" do
      get "/api/v1/trade/pricing"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({
        "wine_review_fee" => {
          "amount" => "50.00",
          "currency" => "AUD",
          "unit" => "bottle"
        }
      })
    end

    it "returns the updated fee when configured by admin" do
      admin = User.create!(first_name: "FeeAdmin", email: "fee-admin@example.com", password: "password123")
      admin.roles << Role.find_or_create_by!(name: "Admin")

      sign_in admin
      patch "/api/v1/configuration",
            params: { wine_review_fee_amount: "75.50", wine_review_fee_currency: "USD" }, as: :json

      # Now request pricing as unauthenticated user
      sign_out admin
      get "/api/v1/trade/pricing"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({
        "wine_review_fee" => {
          "amount" => "75.50",
          "currency" => "USD",
          "unit" => "bottle"
        }
      })
    end

    after do
      AppSetting.where(key: %w[wine_review_fee_amount wine_review_fee_currency]).destroy_all
    end
  end
end