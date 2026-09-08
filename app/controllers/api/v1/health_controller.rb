class Api::V1::HealthController < ApplicationController
  # Public liveness check — no auth, no version/env/stack details exposed.
  skip_before_action :authenticate_user!

  # Detailed diagnostics are admin-only.
  before_action :authenticate_admin!, only: :detailed

  # GET /api/v1/health
  def index
    if database_connected?
      render json: { status: "ok" }
    else
      render json: { status: "error" }, status: :service_unavailable
    end
  end

  # GET /api/v1/health/detailed — admin-only diagnostic endpoint.
  def detailed
    db_ok = database_connected?
    payload = {
      status: db_ok ? "ok" : "error",
      service: "wine-api",
      database: db_ok ? "ok" : "error",
      storage: storage_healthy? ? "ok" : "error",
      environment: Rails.env,
      version: BACK_END_VERSION, # single source: config/initializers/app_version.rb
      timestamp: Time.current.utc.iso8601,
      database_details: db_connection_info,
      storage_details: storage_info,
      server: server_info,
      endpoint: endpoint_info
    }
    render json: payload, status: db_ok ? :ok : :service_unavailable
  end

  private

  def authenticate_admin!
    unless current_user
      return render json: { error: "Authentication required" }, status: :unauthorized
    end
    return if current_user.admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def database_connected?
    ActiveRecord::Base.connection.active?
  rescue StandardError
    false
  end

  # ActiveStorage health probe. Merely calling `exist?` on a key that was
  # never written returns false on every backend — it cannot distinguish
  # "bucket reachable but empty" from "bucket unreachable", so it would
  # report "error" forever on a healthy-but-fresh bucket. Instead, do a
  # real round trip: write a tiny probe object, then delete it. Any failure
  # (auth, network, bucket missing) raises and flips the check to false.
  def storage_healthy?
    service = ActiveStorage::Blob.service
    return true if service.exist?("health-check")

    service.upload("health-check", StringIO.new("ping"))
    service.delete("health-check")
    true
  rescue StandardError => e
    Rails.logger.warn("[health] storage check failed: #{e.class}: #{e.message}")
    false
  end

  # Where uploaded files are stored. Introspects the configured
  # ActiveStorage service without ever exposing credentials:
  #   * S3-family services (Supabase S3, AWS, R2, Minio…) expose the bucket
  #     name plus the region/endpoint the SDK was configured with.
  #   * DiskService exposes the filesystem root it writes to.
  # Every accessor is resolved defensively so an unexpected service class
  # can never 500 the diagnostic endpoint.
  def storage_info
    service = ActiveStorage::Blob.service
    info = {
      service: safe_service_value(service, :name),
      service_class: service.class.name,
      bucket: safe_service_value(service, :bucket) { |b| b.respond_to?(:name) ? b.name : b },
      region: s3_region(service),
      endpoint: safe_service_value(service, :client) { |c| c.config&.endpoint&.to_s },
      root: safe_service_value(service, :root) { |r| r.to_s },
      public: ENV["ACTIVE_STORAGE_PUBLIC"].present? || safe_service_value(service, :public?)
    }
    info.compact_blank.blank? ? fallback_storage_info : info
  rescue StandardError
    fallback_storage_info
  end

  def fallback_storage_info
    { service: nil, service_class: nil, bucket: nil, region: nil,
      endpoint: nil, root: nil, public: nil }
  end

  # Resolve an accessor on the storage service, returning nil (or the block's
  # transformed value) when the service class doesn't implement it or the
  # nested value blows up. Keeps storage_info total — it can never raise.
  def safe_service_value(object, key)
    value = object.public_send(key)
    value = yield(value) if block_given? && !value.nil?
    value
  rescue StandardError
    nil
  end

  # The S3 region lives on the SDK client config, not the service itself.
  # Only S3-family services have a `client` with a config — Disk and GCS
  # return nil here, which is correct.
  def s3_region(service)
    return nil unless service.respond_to?(:client)

    service.client&.config&.region
  rescue StandardError
    nil
  end

  # Connection details surfaced to admins. Everything is read-only; we never
  # include credentials. The whole call is wrapped in `rescue` so a broken
  # connection still returns a payload (with nil values) instead of raising.
  #
  # Two layers of config exist:
  #   1. `connection_db_config` — the static config (adapter, host, db name…).
  #      In production this is a `UrlConfig` parsed from DATABASE_URL and
  #      doesn't expose every accessor (e.g. no #port). In dev it can be a
  #      `ConnectionUrlResolver`/HashConfig from database.yml.
  #   2. `connection` — the live adapter, which can answer derived questions
  #      like "which adapter am I?" and the actual adapter's pool config.
  def db_connection_info
    config = ActiveRecord::Base.connection_db_config
    pool = ActiveRecord::Base.connection_pool
    {
      adapter: db_config_value(config, :adapter),
      database: db_config_value(config, :database),
      host: db_config_value(config, :host),
      port: db_config_value(config, :port),
      username: db_config_value(config, :username),
      encoding: db_config_value(config, :encoding),
      pool: safe_pool_value(pool, :size),
      checkout_timeout: safe_pool_value(pool, :checkout_timeout),
      reaping_frequency: reaper_frequency,
      idle_timeout: safe_pool_value(pool, :idle_timeout)
    }
  rescue StandardError
    {
      adapter: nil, database: nil, host: nil, port: nil, username: nil,
      encoding: nil, pool: nil, checkout_timeout: nil,
      reaping_frequency: nil, idle_timeout: nil
    }
  end

  # UrlConfig doesn't respond to every accessor (e.g. #port). Fall back to nil
  # rather than raising when the field is missing — that way the response is
  # always well-formed JSON.
  def db_config_value(config, key)
    config.public_send(key)
  rescue NoMethodError
    nil
  end

  # The pool's accessor surface varies between Rails versions. `size` and
  # `checkout_timeout` are stable; `idle_timeout` is too on Rails 8.x.
  # `reaping_frequency` is *not* on the pool directly — it lives on the
  # `Reaper` instance. We resolve each accessor defensively so the
  # outer `db_connection_info` block can never be blown up by a missing
  # accessor on a specific Rails version.
  def safe_pool_value(pool, key)
    return nil unless pool

    pool.public_send(key)
  rescue NoMethodError
    nil
  end

  def reaper_frequency
    reaper = ActiveRecord::Base.connection_pool&.reaper
    return nil unless reaper&.respond_to?(:frequency)

    reaper.frequency
  rescue StandardError
    nil
  end

  # Server-side runtime info. RENDER env is exposed because the app is hosted
  # on Render in production and admins frequently want to confirm "am I on
  # prod or staging". Hostname/PID are local-machine data only.
  def server_info
    {
      rails_version: Rails.version,
      ruby: RUBY_DESCRIPTION,
      puma_workers: puma_worker_count,
      hostname: (Socket.gethostname rescue nil),
      pid: Process.pid,
      render: ENV["RENDER"].present?
    }
  end

  def endpoint_info
    {
      scheme: request.scheme,
      host: request.host,
      port: request.port,
      base_url: request.base_url,
      path: request.path
    }
  end

  # Puma exposes a `workers` accessor when running in clustered mode. In the
  # default single-process dev setup it returns 0, which is exactly what we
  # want to surface ("0 workers" = single process).
  def puma_worker_count
    if defined?(Puma) && Puma.respond_to?(:stats) && (stats = Puma.stats).is_a?(String)
      stats[/\A\{.*?"workers":\s*(\d+)/, 1]&.to_i
    end
  rescue StandardError
    nil
  end
end