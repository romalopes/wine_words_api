# Admin-only global configuration endpoint backing the Configuration page.
# Exposes the runtime settings stored in app_settings — currently just the
# "save logs to database" toggle consumed by the Auditable concern.
class Api::V1::ConfigurationsController < ApplicationController
  before_action :authenticate_admin!

  # GET /api/v1/configuration
  def show
    render json: configuration_json
  end

  # PATCH /api/v1/configuration
  # Accepts { logs_saved_to_database: true|false }, plus the email-test settings
  # { use_test_email: true|false, test_email: "..." } — flat or nested under
  # a "configuration" key — and persists whichever are present.
  def update
    settings = configuration_params
    AppSetting.set!(:logs_enabled, settings[:logs_saved_to_database]) if settings.key?(:logs_saved_to_database)
    AppSetting.set!(:use_test_email, settings[:use_test_email]) if settings.key?(:use_test_email)
    AppSetting.set!(:test_email, settings[:test_email]) if settings.key?(:test_email)
    render json: configuration_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") },
           status: :unprocessable_entity
  end

  private

  # Boolean-strong params: ActiveModel's boolean cast handles "true"/"false"/
  # 0/1 so JSON and form-encoded clients both work. Accepts the payload flat
  # or wrapped in a "configuration" key, whichever the client sends.
  def configuration_params
    permitted = params.permit(
      :logs_saved_to_database, :use_test_email, :test_email,
      configuration: [:logs_saved_to_database, :use_test_email, :test_email]
    )
    permitted[:configuration].presence || permitted
  end

  def configuration_json
    {
      logs_saved_to_database: AppSetting.logs_enabled?,
      use_test_email: AppSetting.use_test_email?,
      test_email: AppSetting.test_email,
      settings: AppSetting.where.not(key: AppSetting::RESERVED_KEYS).order(:key).map do |s|
        { id: s.id, key: s.key, value: s.value, updated_at: s.updated_at.iso8601(3) }
      end
    }
  end
end