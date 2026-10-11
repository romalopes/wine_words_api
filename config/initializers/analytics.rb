# config/initializers/analytics.rb
Rails.application.config.analytics = {
  # Rolling deduplication window in seconds (30 minutes = 1800)
  dedup_window_seconds: ENV.fetch("ANALYTICS_DEDUP_WINDOW", 1800).to_i,

  # Advisory lock timeout (ms) — fail fast if DB contended
  lock_timeout_ms: ENV.fetch("ANALYTICS_LOCK_TIMEOUT_MS", 500).to_i,

  # Statement timeout for ingestion transaction (ms)
  statement_timeout_ms: ENV.fetch("ANALYTICS_STATEMENT_TIMEOUT_MS", 200).to_i,

  # Excluded roles (Phase 1 permissions contract)
  excluded_roles: %w[Admin],

  # Whether to track anonymous visitors (Phase 1: yes, with visitor: identity)
  track_anonymous: true,

  # Batch size for background job processing
  batch_size: ENV.fetch("ANALYTICS_BATCH_SIZE", 100).to_i
}.freeze