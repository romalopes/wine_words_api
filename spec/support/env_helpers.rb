# Temporarily overrides ENV values for a block, restoring the previous state
# afterwards. Used by the authentication specs to exercise "provider not
# configured" paths without adding a gem dependency.
#
#   with_env("GOOGLE_CLIENT_ID" => "client-id") do
#     ...
#   end
#
# A nil value removes the variable for the duration of the block.
module EnvHelpers
  def with_env(overrides)
    previous = {}
    overrides.each do |key, value|
      key = key.to_s
      previous[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end

    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end

RSpec.configure do |config|
  config.include EnvHelpers
end