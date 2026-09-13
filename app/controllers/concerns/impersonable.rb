# frozen_string_literal: true

# Concern that provides impersonation support for controllers.
#
# Impersonation lets an admin user act as another (non-admin) user. Two auth
# paths are supported:
#
#   * Web/SSR (cookie session): the target user id is stored in
#     +session[:impersonated_user_id]+.
#   * API/JWT (stateless): the target user id is encoded as an
#     +impersonated_user_id+ claim in the Bearer JWT.
#
# When impersonation is active, +current_user+ returns the *effective* user
# (the impersonated user), while +real_current_user+ always returns the
# authenticated admin. Use +real_current_user+ for admin authorization gates
# so an admin never loses access to admin functionality while impersonating.
module Impersonable
  extend ActiveSupport::Concern

  included do
    helper_method :real_current_user, :impersonating?, :effective_current_user
  end

  # The user we are currently acting as: the impersonated user if impersonation
  # is active, otherwise the real authenticated user. Application code that
  # calls +current_user+ sees this user.
  def effective_current_user
    @effective_current_user ||= resolve_effective_current_user
  end

  # The real authenticated user (the admin who started impersonation), regardless
  # of any active impersonation. Use this for admin authorization gates.
  def real_current_user
    return @real_current_user if defined?(@real_current_user)

    @real_current_user = warden_user
  end

  # True when an impersonation session is active.
  def impersonating?
    impersonated_user_id.present?
  end

  # Issues a JWT for +user+. When +impersonated_user_id+ is provided, the
  # returned token carries an +impersonated_user_id+ claim that this concern
  # decodes on subsequent API requests. Used by the impersonation start/stop
  # endpoints to exchange tokens.
    def issue_jwt_for(user, impersonated_user_id: nil)
    now = Time.current.to_i
    payload = user.jwt_payload.merge(
      "sub" => user.id,
      "scp" => "user",
      "iat" => now,
      "exp" => now + (Devise::JWT.config.expiration_time || 100.years.to_i),
      "jti" => SecureRandom.uuid,
    )
    payload["impersonated_user_id"] = impersonated_user_id if impersonated_user_id

    JWT.encode(payload, jwt_secret, jwt_algorithm)
  end

  private

  # The real user from Warden (works for both session cookie and JWT paths).
  def warden_user
    return nil unless defined?(:warden) && warden

    warden.user(:user)
  rescue StandardError
    nil
  end

  # Override Devise's +current_user+ helper so all application code sees the
  # effective (impersonated) user during impersonation.
  def current_user
    effective_current_user
  end

  # The id of the user being impersonated, or nil. Reads from the session
  # (Web/SSR) or the JWT claim (API) depending on the request type.
  def impersonated_user_id
    @impersonated_user_id ||= read_impersonated_user_id.presence
  end

  def read_impersonated_user_id
    # Prefer the JWT claim (stateless React SPA flow), falling back to the
    # Rails session (Web/SSR flow and same-origin clients).
    if api_request?
      impersonated_user_id_from_jwt || session[:impersonated_user_id]
    else
      session[:impersonated_user_id]
    end
  end

  def impersonated_user_id_from_jwt
    return @jwt_impersonated_user_id if defined?(@jwt_impersonated_user_id)

    @jwt_impersonated_user_id = decoded_jwt_payload&.[]("impersonated_user_id")
  end

  def decoded_jwt_payload
    @decoded_jwt_payload ||= begin
      token = extract_bearer_token
      return nil unless token

      JWT.decode(token, jwt_secret, true, algorithm: jwt_algorithm)[0]
    rescue JWT::DecodeError
      nil
    end
  end

  def extract_bearer_token
    header = request.headers["Authorization"]
    return nil unless header

    scheme, token = header.split(" ", 2)
    return nil unless scheme == "Bearer" && token

    token
  end

  def jwt_secret
    Devise::JWT.config.secret.presence || Rails.application.secret_key_base
  end

  def jwt_algorithm
    Devise::JWT.config.algorithm || "HS256"
  end

  def resolve_effective_current_user
    target_id = impersonated_user_id
    return real_current_user unless target_id

    impersonated = User.find_by(id: target_id)
    impersonated || real_current_user
  end

  def api_request?
    request.path.start_with?("/api/") || request.format.json?
  end
end
