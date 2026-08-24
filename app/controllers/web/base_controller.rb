module Web
  class BaseController < ActionController::Base
    layout "application"

    include Devise::Controllers::Helpers

    helper_method :current_user, :user_signed_in?
  end
end