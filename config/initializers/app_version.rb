# Single source of truth for the backend API version.
# Read once at boot from the VERSION file at the repo root, with an
# ENV override (APP_VERSION) and a sensible final fallback.
APP_VERSION = begin
  ENV["APP_VERSION"].presence || "0.0.20"
end