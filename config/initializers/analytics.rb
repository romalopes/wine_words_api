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

  # Reporting defaults (Phase 6): pagination follows the Api::Paginatable
  # convention (default 20, cap 100); custom ranges are capped so a single
  # report cannot span more history than the UI's "all history" filter.
  default_per_page: ENV.fetch("ANALYTICS_DEFAULT_PER_PAGE", 20).to_i,
  max_per_page: ENV.fetch("ANALYTICS_MAX_PER_PAGE", 100).to_i,
  max_custom_range_days: ENV.fetch("ANALYTICS_MAX_CUSTOM_RANGE_DAYS", 400).to_i,

  # Batch size for background job processing
  batch_size: ENV.fetch("ANALYTICS_BATCH_SIZE", 100).to_i
}.freeze