# Shared Turnstile verification for authentication endpoints (IDENTITY_211).
#
# Include this concern in any controller that needs to verify a Cloudflare
# Turnstile token before processing an authentication request.
#
# The concern expects the action name (e.g. "login", "signup", "password_reset")
# to be passed explicitly. The Turnstile::Verifier validates the token against
# the TURNSTILE_EXPECTED_ACTION environment variable (comma-separated list).
# Shared Turnstile verification for authentication endpoints (IDENTITY_211).
#
# Include this concern in any controller that needs to verify a Cloudflare
# Turnstile token before processing an authentication request.
#
# The concern expects the action name (e.g. "login", "signup", "password_reset")
# to be passed explicitly. The Turnstile::Verifier validates the token against
# the TURNSTILE_EXPECTED_ACTION environment variable (comma-separated list).
module TurnstileVerifiable
  extend ActiveSupport::Concern

  private

  # Verifies the Turnstile token.
  # Returns true on success, false on failure (and renders the error response).
  #
  # @param action [String] the logical action name for logging and expected action check
  # @param token [String, nil] the Turnstile token to verify (already extracted)
  # @return [Boolean]
  def verify_turnstile!(action:, token:)
    token = token.to_s.strip

    # Delegate to the verifier service - it handles enabled? checks, fail-closed,
    # hostname validation, and action matching via TURNSTILE_EXPECTED_ACTION.
    verification = Turnstile::Verifier.call(
      token: token,
      remote_ip: request.remote_ip
    )

    if verification.success?
      true
    else
      Rails.logger.warn("[Turnstile] #{action} rejected: #{verification.error_codes.join(',')}")
      render json: {
        error: "We could not verify your submission. Please refresh the page and try again.",
        turnstile_errors: verification.error_codes
      }, status: :unprocessable_entity
      false
    end
  end
end