class Api::V1::SessionsController < Devise::SessionsController
  respond_to :json

  include Auditable
  include UserSessionPayload
  # Private test-access gate (this controller inherits Devise, not
  # ApplicationController, so the concern is included directly).
  include TestAccess
  audit_actions :create, :destroy

  before_action :remember_user_for_audit

  def log_description
    if action_name == "create"
      @audit_user ? "User logged in" : "Login attempt"
    else
      @audit_user ? "User logged out" : "Logout"
    end
  end

  def log_objects
    [@audit_user].compact
  end

  def remember_user_for_audit
    @audit_user = current_user
  end

  private

  def respond_with(current_user, _opts = {})
    if current_user.persisted?
      render_user_session(current_user, status: :ok)
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def respond_to_on_destroy(_current_user = nil)
    head :no_content
  end
end