# Devise test helpers for request specs.
# Include Devise::Test::IntegrationHelpers in any type: :request spec that
# needs to call sign_in / sign_out with Devise-managed users.
RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :request
end
