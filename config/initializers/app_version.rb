# Single source of truth for the Rails application version.
# Loaded once at boot and reused by Api::V1::HealthController and helpers.
module AppVersion
  VERSION = "0.0.20"
end
