class Api::V1::PasswordsController < Devise::PasswordsController
  respond_to :json

  # POST /api/v1/auth/password
  # Always respond 200 (never reveal whether the email exists). In
  # development/test, expose the reset token/link so the flow can be
  # exercised without a real SMTP server.
  def create
    self.resource = resource_class.find_or_initialize_with_errors(
      resource_class.reset_password_keys, resource_params, :not_found
    )
    raw_token = nil

    if resource.persisted?
      # Generate + persist a reset token exactly like Devise does, but keep
      # the raw value so it can be surfaced in development/test.
      raw_token, _enc = Devise.token_generator.generate(resource_class, :reset_password_token)
      resource.reset_password_token =
        Devise.token_generator.digest(resource_class, :reset_password_token, raw_token)
      resource.reset_password_sent_at = Time.now.utc
      resource.save(validate: false)
      resource.send(:send_devise_notification, :reset_password_instructions, raw_token, {})
    end

    render json: create_response_payload(raw_token), status: :ok
  end

  # PATCH /api/v1/auth/password
  def update
    self.resource = resource_class.reset_password_by_token(resource_params)

    if resource.errors.empty?
      resource.unlock_access! if unlockable?(resource)
      sign_in(resource_name, resource)

      render json: {
        user: { id: resource.id, email: resource.email, name: resource.name, roles: resource.role_names }
      }, status: :ok
    else
      render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def create_response_payload(raw_token)
    payload = {
      message: "If an account exists for #{resource_params[:email]}, " \
               "you will receive an email with instructions to reset your password."
    }

    if Rails.env.development? || Rails.env.test?
      payload[:reset_password_token] = raw_token
      payload[:reset_url] = frontend_reset_url(raw_token)
    end

    payload
  end

  def frontend_reset_url(token)
    base = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    "#{base}/reset-password?reset_password_token=#{token}"
  end

  # Devise API-only setup disables navigational formats, so the standard
  # `sign_in_after_reset_password` still applies via sign_in below.
  def unlockable?(resource)
    resource.respond_to?(:unlock_access!) && resource.respond_to?(:unlock_strategy_enabled?) &&
      resource.unlock_strategy_enabled?(:email)
  end
end