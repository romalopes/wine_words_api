# Public Contact form endpoint (IDENTITY_209 Phase 1).
#
#   POST /api/v1/contact_messages
#
# Authentication is deliberately absent: visitors contact the team without an
# account. Abuse protection is layered — Cloudflare Turnstile (server-side),
# Rack::Attack throttles, a honeypot and the strict allowlist below. The
# allowlist makes it impossible to set status, timestamps, notification
# recipients or any internal field from the public form.
#
# The response is intentionally minimal: it confirms receipt without exposing
# the record id, recipients or delivery state.
class Api::V1::ContactMessagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[create]
  skip_before_action :enforce_email_verification!, only: %i[create]
  skip_before_action :reject_deleted_user!, only: %i[create]

  def create
    result = Contact::Messages::Submit.call(
      params: contact_message_params,
      remote_ip: request.remote_ip
    )

    case result.status
    when :created, :discarded
      # A discarded honeypot looks identical to success on purpose.
      render json: { status: "received" }, status: :created
    when :turnstile_failed
      render json: {
        error: "We could not verify your submission. Please refresh the page and try again."
      }, status: :unprocessable_entity
    when :invalid
      render json: {
        error: result.contact_message.errors.full_messages.to_sentence,
        errors: result.contact_message.errors.full_messages,
        # Field-keyed messages let the form highlight the offending input.
        details: result.contact_message.errors.to_hash
      }, status: :unprocessable_entity
    end
  end

  private

  # The ONLY fields an anonymous visitor may set. `website` is the honeypot and
  # is never persisted.
  def contact_message_params
    params.permit(
      :name,
      :email,
      :contact_type,
      :subject,
      :message,
      :turnstile_token,
      :website
    )
  end
end
