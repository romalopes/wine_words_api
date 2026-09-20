# GET /api/v1/email-verifications/:token
#
# Marks the token as verified by consuming it (single use + expiry). On success
# returns a JSON payload so the React SPA can update the auth state / redirect
# back to the login page with a success message. On failure returns 422 with a
# generic error — no user existence is disclosed.
class Api::V1::EmailVerificationsController < ApplicationController
  def show
    result = EmailVerificationService.verify(params.fetch(:token, ""))
    if result
      render json: {
        status: "verified",
        email: result.email,
        user_name: result.user_name
      }
    else
      render json: { error: "Verification link is invalid or has expired." },
             status: :unprocessable_entity
    end
  end
end
