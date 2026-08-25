# Shared authentication gate for server-rendered scaffold controllers.
# Restricts write actions to signed-in (Devise/Warden) users.
module RequireLogin
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user, only: [:new, :edit, :create, :update, :destroy]
    before_action :require_login, only: [:new, :edit, :create, :update, :destroy]
  end

  private

  def set_current_user
    @current_user = warden.user(:user) if respond_to?(:warden) && warden
  end

  def require_login
    return if @current_user.present?

    redirect_to login_path, alert: "You must be signed in to do that."
  end
end
