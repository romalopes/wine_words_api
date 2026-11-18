# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  # `message` covers contact-form and conversation bodies: request logging must
  # never write free-text content, and `token` already covers turnstile_token.
  :passw, :email, :secret, :token, :message, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
