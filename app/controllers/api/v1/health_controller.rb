class Api::V1::HealthController < ApplicationController
  # Public liveness check — no auth, no version/env/stack details exposed.
  skip_before_action :authenticate_user!

  # Detailed diagnostics are admin-only.
  before_action :authenticate_admin!, only: :detailed

  # GET /api/v1/health
  def index
    if database_connected?
      render json: { status: "ok" }
    else
      render json: { status: "error" }, status: :service_unavailable
    end
  end

  # GET /api/v1/health/detailed — admin-only diagnostic endpoint.
  def detailed
    render json: {
      status: database_connected? ? "ok" : "error",
      service: "wine-api",
      database: database_connected? ? "ok" : "error",
      storage: storage_healthy? ? "ok" : "error",
      environment: Rails.env,
      version: BACK_END_VERSION, # single source: config/initializers/app_version.rb
      timestamp: Time.current.utc.iso8601
    }, status: database_connected? ? :ok : :service_unavailable
  end

  private

  def authenticate_admin!
    unless current_user
      return render json: { error: "Authentication required" }, status: :unauthorized
    end
    return if current_user.super_admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  def storage_healthy?
    ActiveStorage::Blob.service.respond_to?(:head) && ActiveStorage::Blob.service.head("health-check")
  rescue StandardError
    false
  end
end