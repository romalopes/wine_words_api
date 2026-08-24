# View helper exposing Devise auth state to all server-rendered templates,
# including those rendered by scaffold controllers that do not include the
# Devise controller helpers.
module AuthHelper
  def current_user
    @__auth_helper_current_user ||=
      if respond_to?(:warden) && warden
        warden.user(:user)
      end
  end

  def user_signed_in?
    current_user.present?
  end
end