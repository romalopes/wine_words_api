require "rails_helper"
require "devise"

RSpec.describe "Api::V1::Configurations", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) do
    user = User.create!(first_name: "CfgAdmin", email: "cfg-admin@example.com", password: "password123")
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let(:plain_user) do
    User.create!(first_name: "CfgGuest", email: "cfg-guest@example.com", password: "password123")
  end

  after do
    # Restore the global defaults so other specs are not affected by the toggles.
    AppSetting.where(key: %w[logs_enabled use_test_email test_email mail_transport
                             wine_review_fee_amount wine_review_fee_currency]).destroy_all
  end

  describe "GET /api/v1/configuration" do
    it "requires authentication" do
      get "/api/v1/configuration"
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a non-admin authenticated user" do
      sign_in plain_user
      get "/api/v1/configuration"
      expect(response).to have_http_status(:forbidden)
    end

    it "returns the defaults when unset" do
      sign_in admin
      get "/api/v1/configuration"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq({
        "logs_saved_to_database" => true,
        "use_test_email" => false,
        # Falls back to the MAIL_REPLY_TO env var, which is unset in CI.
        "test_email" => ENV["MAIL_REPLY_TO"],
        "mail_transport" => "auto",
        "show_taste_parameters" => "true",
        "wine_review_fee_amount" => "50.00",
        "wine_review_fee_currency" => "AUD",
        "invoice_gst_rate" => "0.1",
        "invoice_from_email" => AppSetting::DEFAULTS.fetch("invoice_from_email"),
        "settings" => []
      })
    end
  end

  describe "PATCH /api/v1/configuration" do
    it "requires authentication" do
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects a non-admin authenticated user" do
      sign_in plain_user
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "persists the toggle and echoes it back" do
      sign_in admin
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["logs_saved_to_database"]).to be(false)
      expect(AppSetting.logs_enabled?).to be(false)

      patch "/api/v1/configuration", params: { logs_saved_to_database: true }, as: :json
      expect(JSON.parse(response.body)["logs_saved_to_database"]).to be(true)
      expect(AppSetting.logs_enabled?).to be(true)
    end

    it "accepts a nested configuration payload (no unpermitted-parameter warning)" do
      sign_in admin
      allow(Rails.logger).to receive(:warn)

      patch "/api/v1/configuration",
            params: { configuration: { logs_saved_to_database: false } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["logs_saved_to_database"]).to be(false)
      expect(AppSetting.logs_enabled?).to be(false)
      expect(Rails.logger).not_to have_received(:warn).with(a_string_including("Unpermitted parameter"))
    end

    it "persists the email test settings and echoes them back" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { use_test_email: true, test_email: "tester@example.com" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["use_test_email"]).to be(true)
      expect(JSON.parse(response.body)["test_email"]).to eq("tester@example.com")
      expect(AppSetting.use_test_email?).to be(true)
      expect(AppSetting.test_email).to eq("tester@example.com")
    end

    it "persists the mail transport setting and echoes it back" do
      sign_in admin
      patch "/api/v1/configuration", params: { mail_transport: "smtp" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["mail_transport"]).to eq("smtp")
      expect(AppSetting.mail_transport).to eq("smtp")

      patch "/api/v1/configuration", params: { mail_transport: "auto" }, as: :json
      expect(JSON.parse(response.body)["mail_transport"]).to eq("auto")
      expect(AppSetting.mail_transport).to eq("auto")
    end

    it "accepts mail_transport nested under configuration" do
      sign_in admin
      allow(Rails.logger).to receive(:warn)
      patch "/api/v1/configuration",
            params: { configuration: { mail_transport: "brevo" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["mail_transport"]).to eq("brevo")
      expect(AppSetting.mail_transport).to eq("brevo")
      expect(Rails.logger).not_to have_received(:warn).with(a_string_including("Unpermitted parameter"))
    end

    it "leaves mail_transport untouched when absent" do
      sign_in admin
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(AppSetting.mail_transport).to eq("auto") # default, never set
    end

    it "persists email test settings sent nested under configuration" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { configuration: { use_test_email: true,
                                       test_email: "nested@example.com" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["use_test_email"]).to be(true)
      expect(AppSetting.use_test_email?).to be(true)
      expect(AppSetting.test_email).to eq("nested@example.com")
    end

    it "leaves settings untouched when their keys are absent" do
      sign_in admin
      patch "/api/v1/configuration", params: { use_test_email: true }, as: :json
      expect(AppSetting.logs_enabled?).to be(true) # default, never set
    end

    it "persists the wine review fee amount and currency" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { wine_review_fee_amount: "75.50", wine_review_fee_currency: "USD" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["wine_review_fee_amount"]).to eq("75.50")
      expect(JSON.parse(response.body)["wine_review_fee_currency"]).to eq("USD")
      expect(AppSetting.wine_review_fee_amount).to eq(BigDecimal("75.50"))
      expect(AppSetting.wine_review_fee_currency).to eq("USD")
    end

    it "accepts wine review fee nested under configuration" do
      sign_in admin
      allow(Rails.logger).to receive(:warn)
      patch "/api/v1/configuration",
            params: { configuration: { wine_review_fee_amount: "100.00", wine_review_fee_currency: "EUR" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["wine_review_fee_amount"]).to eq("100.00")
      expect(JSON.parse(response.body)["wine_review_fee_currency"]).to eq("EUR")
      expect(Rails.logger).not_to have_received(:warn).with(a_string_including("Unpermitted parameter"))
    end

    it "rejects negative fee amount" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { wine_review_fee_amount: "-10.00" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Fee amount must be non-negative")
    end

    it "rejects fee amount with more than 2 decimal places" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { wine_review_fee_amount: "50.123" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Fee amount must have at most 2 decimal places")
    end

    it "rejects unsupported currency" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { wine_review_fee_currency: "XYZ" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("Unsupported currency: XYZ")
    end

    it "leaves wine review fee untouched when absent" do
      sign_in admin
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(AppSetting.wine_review_fee_amount).to eq(BigDecimal("50.00")) # default
      expect(AppSetting.wine_review_fee_currency).to eq("AUD")
    end

    it "persists the invoice GST rate" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { invoice_gst_rate: "0.15" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["invoice_gst_rate"]).to eq("0.15")
      expect(AppSetting.invoice_gst_rate).to eq(BigDecimal("0.15"))
    end

    it "accepts invoice GST rate nested under configuration" do
      sign_in admin
      allow(Rails.logger).to receive(:warn)
      patch "/api/v1/configuration",
            params: { configuration: { invoice_gst_rate: "0.12" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["invoice_gst_rate"]).to eq("0.12")
      expect(Rails.logger).not_to have_received(:warn).with(a_string_including("Unpermitted parameter"))
    end

    it "rejects negative GST rate" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { invoice_gst_rate: "-0.05" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("GST rate must be non-negative")
    end

    it "rejects GST rate with more than 4 decimal places" do
      sign_in admin
      patch "/api/v1/configuration",
            params: { invoice_gst_rate: "0.12345" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to eq("GST rate must have at most 4 decimal places")
    end

    it "leaves invoice GST rate untouched when absent" do
      sign_in admin
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(AppSetting.invoice_gst_rate).to eq(BigDecimal("0.10")) # default
    end

    it "persists the invoice from email and echoes it back" do
      sign_in admin
      patch "/api/v1/configuration", params: { invoice_from_email: "accounts@winewords.com" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["invoice_from_email"]).to eq("accounts@winewords.com")
      expect(AppSetting.invoice_from_email).to eq("accounts@winewords.com")
    end

    it "accepts the invoice from email nested under configuration" do
      sign_in admin
      patch "/api/v1/configuration", params: { configuration: { invoice_from_email: "nested@winewords.com" } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(AppSetting.invoice_from_email).to eq("nested@winewords.com")
    end

    it "trims surrounding whitespace from the invoice from email" do
      sign_in admin
      patch "/api/v1/configuration", params: { invoice_from_email: "  padded@winewords.com  " }, as: :json
      expect(response).to have_http_status(:ok)
      expect(AppSetting.invoice_from_email).to eq("padded@winewords.com")
    end

    it "rejects an invalid invoice from email" do
      sign_in admin
      patch "/api/v1/configuration", params: { invoice_from_email: "not-an-email" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("valid email")
      expect(AppSetting.invoice_from_email).to eq(AppSetting::DEFAULTS.fetch("invoice_from_email")) # unchanged default
    end

    it "rejects a blank invoice from email" do
      sign_in admin
      patch "/api/v1/configuration", params: { invoice_from_email: "   " }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["error"]).to include("blank")
    end

    it "leaves the invoice from email untouched when absent" do
      sign_in admin
      patch "/api/v1/configuration", params: { invoice_from_email: "custom@winewords.com" }, as: :json
      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json
      expect(AppSetting.invoice_from_email).to eq("custom@winewords.com")
    end

    it "suppresses audit log persistence while disabled and restores it when re-enabled" do
      sign_in admin
      expect {
        patch "/api/v1/account", params: { first_name: "cfg_admin_x" }, as: :json
      }.to change(Log, :count).by(1)

      patch "/api/v1/configuration", params: { logs_saved_to_database: false }, as: :json

      expect {
        patch "/api/v1/account", params: { first_name: "cfg_admin_y" }, as: :json
      }.not_to change(Log, :count)

      patch "/api/v1/configuration", params: { logs_saved_to_database: true }, as: :json

      expect {
        patch "/api/v1/account", params: { first_name: "cfg_admin_z" }, as: :json
      }.to change(Log, :count).by(1)
    end
  end
end
