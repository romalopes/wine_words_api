module Web
  class BaseController < ActionController::Base
    layout "application"

    include Devise::Controllers::Helpers
    include Auditable

    helper_method :current_user, :user_signed_in?
  end
end