class ApplicationController < ActionController::API
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