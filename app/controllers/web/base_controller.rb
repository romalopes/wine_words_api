module Web
  class BaseController < ActionController::Base
    layout "application"

    include Devise::Controllers::Helpers
    include Auditable
    include Impersonable

    helper_method :current_user, :user_signed_in?, :real_current_user, :impersonating?
  end
end