# Public Trade submissions endpoint (IDENTITY_206 Phase 3).
#
# POST /api/v1/trade/submissions
#
# Authentication is deliberately ABSENT: anyone may submit (§1.2). Abuse
# protection comes from the platform infrastructure (Turnstile + Rack::Attack
# throttles) and from the strong-parameter allowlist below, which makes it
# impossible to set submitter_id, producer_id, status, prices paid, or any
# editorial field through the public form.
#
# Idempotency: an optional client-generated X-Idempotency-Key header makes
# retries return the original submission instead of duplicating it.
class Api::V1::Trade::SubmissionsController < ApplicationController
  include TurnstileVerifiable

  skip_before_action :authenticate_user!, only: %i[create check_email]
  skip_before_action :enforce_email_verification!, only: %i[create check_email]
  skip_before_action :reject_deleted_user!, only: %i[create check_email]

  rescue_from Trade::Error, with: :render_trade_error

  # GET /api/v1/trade/submissions/check_email?email=...
  # Checks if an email is associated with an existing user account.
  # Returns { exists: true } or { exists: false, message: "..." }
  def check_email
    email = params[:email]&.strip&.downcase
    return render json: { exists: false }, status: :bad_request if email.blank?

    user = User.find_by("LOWER(email) = ?", email)
    if user
      render json: { exists: true }
    else
      render json: { exists: false }
    end
  end

  def create
    # Cloudflare Turnstile (server-side, fail-closed). Disabled outside
    # production unless TURNSTILE_ENABLED is set, so dev/test are unaffected.
    return unless verify_turnstile!(action: "trade_submission", token: params[:turnstile_token])

    # Idempotency key: prefer the X-Idempotency-Key header, falling back to the
    # body param (the merge must not clobber the param with a nil header).
    idempotency_key =
      request.headers["X-Idempotency-Key"].presence || params[:idempotency_key]

    # If user is authenticated, link submission to them
    submitter = current_user

    result = Trade::Submissions::Create.call(
      submission_params.merge(idempotency_key: idempotency_key),
      submitted_ip: request.remote_ip,
      submitter: submitter
    )
    # Send confirmation email to the submitter (async via deliver_later).
    # The raw guest token is passed through — the mailer must NOT regenerate
    # it, or the digest on the package would be rotated and the link shown to
    # the submitter (and in the response below) would stop working.
    # Replays return the original package with no fresh token — no new email.
    unless result.replayed
      TradeSubmissionsMailer.confirmation(result.package.id, result.guest_token).deliver_later
      # Editorial team: one in-app notification plus one email per Editor/Admin
      # account (best-effort — it never fails the submission).
      Trade::Submissions::NotifyStaff.call(package: result.package, submitter: submitter)
    end

    render json: {
      package_reference: result.package.id,
      status: result.package.status,
      guest_token: result.guest_token,
      guest_url: guest_url(result.guest_token),
      replayed: result.replayed
    }, status: :created
  end

  private

  # Explicit allowlist — the ONLY fields an anonymous visitor may set.
  # Accepts either a flat payload (`contact_snapshot`, `wines` at top level)
  # or a nested `submission` wrapper containing the same fields. This lets
  # frontends that wrap params under `submission:` avoid the "unpermitted
  # parameter" warning while keeping the same strong-parameter contract.
  def submission_params
    source = params[:submission].presence || params
    source.permit(
      :idempotency_key,
      :turnstile_token,
      contact_snapshot: %i[
        company_name contact_name email phone address country website role notes
      ],
      wines: %i[
        wine_name vintage quantity region appellation grape_varieties abv volume_ml
        closure_type tasting_notes technical_sheet_url trade_price retail_price
        sample_available sample_quantity
      ]
    ).to_hash.symbolize_keys
  end

  def guest_url(token)
    "#{EmailVerification.frontend_url}/trade/packages/#{token}"
  end

  def render_trade_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end
