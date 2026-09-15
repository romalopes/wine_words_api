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
  # Accepts { logs_saved_to_database: true|false } and persists it.
  def update
    AppSetting.set!(:logs_enabled, configuration_params[:logs_saved_to_database])
    render json: configuration_json
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.join(", ") },
           status: :unprocessable_entity
  end

  private

  # Boolean-strong param: ActiveModel's boolean cast handles "true"/"false"/
  # 0/1 so JSON and form-encoded clients both work.
  def configuration_params
    params.permit(:logs_saved_to_database)
  end

  def configuration_json
    {
      logs_saved_to_database: AppSetting.logs_enabled?
    }
  end

  def authenticate_admin!
    return render json: { error: "Authentication required" }, status: :unauthorized unless current_user
    return if real_current_user&.admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end
end