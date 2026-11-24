# Admin-only global configuration endpoint backing the Configuration page.
# Exposes the runtime settings stored in app_settings — currently the
# "save logs to database" toggle, email-test settings, Wine Words
# review fee (IDENTITY_214), and invoice GST rate (IDENTITY_214 Phase 12).
class Api::V1::ConfigurationsController < ApplicationController
  before_action :authenticate_admin!

  # GET /api/v1/configuration
  def show
    render json: configuration_json
  end

  # PATCH /api/v1/configuration
  # Accepts { logs_saved_to_database: true|false }, plus the email-test settings
  # { use_test_email: true|false, test_email: "..." }, Wine Words review fee
  # { wine_review_fee_amount: "50.00", wine_review_fee_currency: "AUD" },
  # invoice GST rate { invoice_gst_rate: "0.10" }, and the invoice sender
  # address { invoice_from_email: "billing@winewords.com" } — flat or nested
  # under a "configuration" key — and persists whichever are present.
  def update
    settings = configuration_params
    AppSetting.set!(:logs_enabled, settings[:logs_saved_to_database]) if settings.key?(:logs_saved_to_database)
    AppSetting.set!(:use_test_email, settings[:use_test_email]) if settings.key?(:use_test_email)
    AppSetting.set!(:test_email, settings[:test_email]) if settings.key?(:test_email)
    AppSetting.set!(:mail_transport, settings[:mail_transport]) if settings.key?(:mail_transport)
    AppSetting.set!(:show_taste_parameters, settings[:show_taste_parameters]) if settings.key?(:show_taste_parameters)
    if settings.key?(:wine_review_fee_amount) || settings.key?(:wine_review_fee_currency)
      amount = settings.fetch(:wine_review_fee_amount) { AppSetting.wine_review_fee_amount.to_s("F") }
      currency = settings.fetch(:wine_review_fee_currency) { AppSetting.wine_review_fee_currency }
      AppSetting.validate_wine_review_fee!(amount, currency)
      AppSetting.set!(:wine_review_fee_amount, amount)
      AppSetting.set!(:wine_review_fee_currency, currency)
    end
    if settings.key?(:invoice_gst_rate)
      rate = settings[:invoice_gst_rate]
      rate_bd = BigDecimal(rate.to_s)
      raise ArgumentError, "GST rate must be non-negative" if rate_bd.negative?
      raise ArgumentError, "GST rate must have at most 4 decimal places" if rate_bd.scale > 4
      AppSetting.set!(:invoice_gst_rate, rate)
    end
    if settings.key?(:invoice_from_email)
      email = AppSetting.validate_invoice_from_email!(settings[:invoice_from_email])
      AppSetting.set!(:invoice_from_email, email)
    end
    # New settings (IDENTITY_206 Phase 12 / IDENTITY_214 Phase 12)
    AppSetting.set!(:sample_shipping_address, settings[:sample_shipping_address]) if settings.key?(:sample_shipping_address)
    AppSetting.set!(:invoice_bank_name, settings[:invoice_bank_name]) if settings.key?(:invoice_bank_name)
    AppSetting.set!(:invoice_account_name, settings[:invoice_account_name]) if settings.key?(:invoice_account_name)
    AppSetting.set!(:invoice_bsb, settings[:invoice_bsb]) if settings.key?(:invoice_bsb)
    AppSetting.set!(:invoice_account_number, settings[:invoice_account_number]) if settings.key?(:invoice_account_number)
    render json: configuration_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") },
           status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  # Boolean-strong params: ActiveModel's boolean cast handles "true"/"false"/
  # 0/1 so JSON and form-encoded clients both work. Accepts the payload flat
  # or wrapped in a "configuration" key, whichever the client sends.
  def configuration_params
    permitted = params.permit(
      :logs_saved_to_database, :use_test_email, :test_email, :mail_transport, :show_taste_parameters,
      :wine_review_fee_amount, :wine_review_fee_currency, :invoice_gst_rate, :invoice_from_email,
      :sample_shipping_address,
      :invoice_bank_name, :invoice_account_name, :invoice_bsb, :invoice_account_number,
      configuration: [ :logs_saved_to_database, :use_test_email, :test_email, :mail_transport, :show_taste_parameters,
                       :wine_review_fee_amount, :wine_review_fee_currency, :invoice_gst_rate, :invoice_from_email,
                       :sample_shipping_address,
                       :invoice_bank_name, :invoice_account_name, :invoice_bsb, :invoice_account_number ]
    )
    permitted[:configuration].presence || permitted
  end

  def configuration_json
    {
      logs_saved_to_database: AppSetting.logs_enabled?,
      use_test_email: AppSetting.use_test_email?,
      test_email: AppSetting.test_email,
      mail_transport: AppSetting.mail_transport,
      show_taste_parameters: AppSetting.show_taste_parameters?,
      wine_review_fee_amount: AppSetting.wine_review_fee_amount_formatted,
      wine_review_fee_currency: AppSetting.wine_review_fee_currency,
      invoice_gst_rate: AppSetting.invoice_gst_rate.to_s("F"),
      invoice_from_email: AppSetting.invoice_from_email,
      # New settings (IDENTITY_206 Phase 12 / IDENTITY_214 Phase 12)
      sample_shipping_address: AppSetting.sample_shipping_address,
      invoice_bank_name: AppSetting.invoice_bank_name,
      invoice_account_name: AppSetting.invoice_account_name,
      invoice_bsb: AppSetting.invoice_bsb,
      invoice_account_number: AppSetting.invoice_account_number,
      settings: AppSetting.where.not(key: AppSetting::RESERVED_KEYS).order(:key).map do |s|
        { id: s.id, key: s.key, value: s.value, updated_at: s.updated_at.iso8601(3) }
      end
    }
  end
end
