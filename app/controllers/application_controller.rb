class ApplicationController < ActionController::Base
  # This controller is the base for the JSON API consumed by the React app
  # (cross-origin from localhost:5173 in development). Auth is handled via
  # Bearer JWTs (devise-jwt), not cookies, so CSRF/origin checks are disabled
  # here. Server-rendered Web::* controllers inherit ActionController::Base
  # directly and keep standard CSRF protection.
  skip_forgery_protection

  before_action :authenticate_user!

  def render_resource(resource)
    if resource.errors.empty?
      render json: resource
    else
      validation_error(resource)
    end
  end

  def validation_error(resource)
    render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
  end
end