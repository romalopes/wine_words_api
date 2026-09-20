class Api::V1::TestAccessController < ApplicationController
  # These endpoints must be reachable before any test access exists.
  skip_before_action :authenticate_user!, raise: false
  allow_test_access only: %i[create show]

  # Brute-force protection for the password check (Rails 8 built-in,
  # backed by the Solid Cache store in production).
  rate_limit to: 10, within: 1.minute, only: :create

  # POST /api/v1/test_access — validates the configured password and issues a
  # signed, expiring token. A wrong password is a 401 with no hint about the
  # configured value.
  def create
    unless TestAccessToken.enabled?
      return render json: { authenticated: true, token: nil, disabled: true }
    end

    if TestAccessToken.matches?(params[:password])
      render json: {
        authenticated: true,
        token: TestAccessToken.generate,
        expires_at: TestAccessToken.expiration.from_now.utc.iso8601
      }
    else
      render json: { authenticated: false, error: "Invalid password" },
             status: :unauthorized
    end
  end

  # GET /api/v1/test_access — verifies the token sent in the
  # X-Test-Access-Token header; the SPA calls this on boot to detect an
  # expired credential.
  def show
    # Gate disabled (no TEST_ACCESS_PASSWORD configured): everything is open,
    # so verification reports success so the SPA stays unlocked.
    unless TestAccessToken.enabled?
      return render json: { authenticated: true, disabled: true }
    end

    if TestAccessToken.valid?(request.headers[TestAccess::TEST_ACCESS_HEADER])
      render json: { authenticated: true }
    else
      render json: {
        authenticated: false,
        error: "Invalid or expired test access token",
        code: "test_access_required"
      }, status: :unauthorized
    end
  end
end
