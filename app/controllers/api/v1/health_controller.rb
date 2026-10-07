class Api::V1::HealthController < ApplicationController
  # Public liveness check — no auth, no version/env/stack details exposed.
  #
  # Only `index` is auth-free. `detailed` MUST keep running
  # `authenticate_user!` so the devise-jwt strategy actually validates the
  # Bearer token and populates Warden. If it were skipped, `warden.user(:user)`
  # would return nil (Warden's `user` accessor only *reads* an already
  # authenticated user, it does not run strategies) and the admin gate would
  # 401 even for a valid admin token — which is exactly what the React SPA
  # sends.
  skip_before_action :authenticate_user!, only: :index

  # Public liveness probe stays reachable without the private test-access
  # token (`detailed` remains gated by both layers).
  skip_before_action :require_test_access, only: :index

  # Detailed diagnostics and the search-index report are admin-only.
  #
  # One declaration for both actions: `before_action` is deduplicated by filter
  # name, so a second `before_action :authenticate_admin!, only: ...` would
  # replace this one's action list rather than add to it, and would quietly
  # un-gate whatever it stopped naming.
  before_action :authenticate_admin!, only: %i[detailed search_index]


  # GET /api/v1/health
  def index
    db_ok = database_connected?
    payload = {
      status: db_ok ? "ok" : "error",
      database: db_ok ? "ok" : "error",
      version: AppVersion::VERSION
    }
    render json: payload, status: db_ok ? :ok : :service_unavailable
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
      version: AppVersion::VERSION, # single source: config/initializers/app_version.rb
      timestamp: Time.current.utc.iso8601,
      database_details: db_connection_info,
      storage_details: storage_info,
      server: server_info,
      endpoint: endpoint_info
    }
    render json: payload, status: db_ok ? :ok : :service_unavailable
  end

  # GET /api/v1/health/search_index — admin-only diagnostic.
  #
  # Reports how much of the full-text index is actually built. Search runs on
  # the `searchable` tsvector columns, and a NULL tsvector satisfies no match,
  # so a table whose vectors were never built answers every `?query=` with an
  # empty list while every other endpoint looks healthy. That is exactly how
  # this went unnoticed until users reported "search returns nothing"; this
  # check turns it into a red row on the ApiHealth page instead.
  #
  # Counts are exact rather than sampled: this is an on-demand admin
  # diagnostic, and the repair (`bin/rails search:reindex`) needs to know the
  # size of the job.
  def search_index
    reviews = Review.search_vector_status
    articles = Article.search_vector_status
    missing = reviews[:missing] + articles[:missing]

    render json: {
      status: missing.zero? ? "ok" : "degraded",
      reviews: reviews,
      articles: articles,
      reindex_command: "bin/rails search:reindex",
      generated_at: Time.current.utc.iso8601
    }
  end

  # GET /api/v1/health/email/transport — public, no auth.
  #
  # Reports the two transports the ApiHealth page needs to render the
  # email-status row: the name the operator configured (`configured_transport`)
  # and the name the mail infrastructure actually resolved for this process
  # (`effective_transport`). Nothing more, nothing less — no tokens, no user.
  def email_transport
    render json: {
      configured_transport: MailTransport.resolve(ENV, logger: Rails.logger),
      effective_transport: MailTransport.effective_transport_name(ENV, logger: Rails.logger)
    }, status: :ok
  end

  # Public transport report — reachable without any user or token.
  #
  # The React ApiHealth page calls this before it has authenticated anyone.
  skip_before_action :authenticate_user!, only: :email_transport
  skip_before_action :require_test_access, only: :email_transport

  # POST /api/v1/health/email/test — admin-only diagnostics.
  #
  # Delivers a single test e-mail through the resolved transport and reports
  # what actually happened. It is a single-write flow: no create/delete pair,
  # no persisted state — the e-mail is delivered straight to the caller's
  # `to` address and nothing is stored.
  #
  # Params:
  #   to       - required, non-empty string (recipient). E.g. "jane@doe.com"
  #   content  - required, non-empty string (plain-text body)
  #   subject  - optional, non-empty string (defaults to a generated subject)
  #
  # Responses:
  #   200 { status: "delivered", configured_transport, effective_transport,
  #         recipients, message, delivered_at } — send completed.
  #   422 { error, code } — a required parameter is missing or has the wrong
  #         type.
  #   500 { error, code, details } — delivery failed (transport errors).
  def send_test_email
    required = { to: params[:to], content: params[:content] }
    required.each do |field, value|
      unless value.is_a?(String) && !value.strip.empty?
        render json: { error: "#{field.to_s.capitalize} must be a non-empty string",
                        code: "invalid_parameter" }, status: :unprocessable_entity
        return
      end
    end

    to = params[:to].strip
    content = params[:content].strip
    subject = params[:subject].to_s.strip.presence

    if Rails.env.test?
      # In the test environment, we use the effective transport name for logging and
      # build a note similar to the original logic.
      requested_transport = ENV["MAIL_TRANSPORT"]
      configured_transport = MailTransport.resolve(ENV, logger: Rails.logger)
      transport_note =
        if requested_transport.present? && requested_transport != "auto"
          if requested_transport != configured_transport
            case requested_transport
            when "brevo"
              key = "BREVO_API_KEY"
            when "resend"
              key = "RESEND_API_KEY"
            when "smtp"
              key = "SMTP_ADDRESS"
            else
              key = nil
            end
            if key
              "MAIL_TRANSPORT=#{requested_transport} requires #{key}; using #{configured_transport} instead."
            else
              "MAIL_TRANSPORT=#{requested_transport} is not supported; using #{configured_transport} instead."
            end
          else
            "MAIL_TRANSPORT=#{requested_transport} (no issues)."
          end
        else
          "MAIL_TRANSPORT not set; using automatic selection (#{configured_transport})."
        end

      transport_to_use = MailTransport.effective_transport_name(ENV, logger: Rails.logger)

      msg = TestEmailMailer.test_email(to: to, content: content, transport: transport_to_use, subject: subject, transport_note: transport_note)
      msg.deliver

      used_transport = transport_to_use
    else
      # In non-test environments, we try transports in order until one succeeds.
      requested_transport = ENV["MAIL_TRANSPORT"]
      configured_transport = MailTransport.resolve(ENV, logger: Rails.logger)

      # Build an ordered list of transports to try (without duplicates)
      transports_to_try = []
      requested = requested_transport.to_s.strip.downcase
      automatic = ["brevo", "resend", "smtp", "file"]

      if requested.present? && requested != "auto"
        transports_to_try << requested unless transports_to_try.include?(requested)
      end
      automatic.each do |t|
        transports_to_try << t unless transports_to_try.include?(t)
      end

      last_error = nil
      used_transport = nil

      transports_to_try.each_with_index do |transport_candidate, index|
        # Build the transport note optimistically: we assume that this candidate will work and that we have tried the previous ones and they failed.
        attempted_so_far = transports_to_try[0..index]
        if attempted_so_far.length > 1
          transport_note = "Attempted transports: #{attempted_so_far.join(', ')}. Finally used: #{transport_candidate}."
        else
          transport_note = "Used transport: #{transport_candidate}."
        end

        begin
          msg = TestEmailMailer.test_email(to: to, content: content, transport: transport_candidate, subject: subject, transport_note: transport_note)
          msg.deliver
          used_transport = transport_candidate
          break
        rescue StandardError => e
          last_error = e
          Rails.logger.warn("Test email transport #{transport_candidate} failed: #{e.message}")
          next
        end
      end

      unless used_transport
        raise last_error || RuntimeError.new("All transports failed")
      end
    end

    render json: {
      status: "delivered",
      configured_transport: configured_transport,
      effective_transport: MailTransport.effective_transport_name(ENV, logger: Rails.logger),
      recipients: [to],
      message: "Test e-mail delivered to #{to} via #{used_transport}.",
      delivered_at: Time.current.utc.iso8601
    }, status: :ok
  rescue StandardError => error
    render json: {
      error: "Delivery failed",
      code: "email_delivery_failed",
      details: error.message
    }, status: :internal_server_error
  end

  # Mirrors the {.authenticate_admin!} gate for the send-test endpoint without
  # sharing the filter name, so the `only: %i[detailed search_index]` action
  # list is not replaced by the new declaration.
  def authenticate_admin_for_send_test!
    authenticate_admin!
  end

  before_action :authenticate_admin_for_send_test!, only: :send_test_email

  private

  # A real round trip instead of `connection.active?`: in a freshly booted
  # process the pooled connection is created lazily, so `active?` reports
  # false until some other query has warmed it — which made a healthy
  # database report "error" 

  def authenticate_admin!
    # Use the REAL authenticated user so an admin who is impersonating a
    # normal user keeps access to admin diagnostics (mirrors the gate in
    # Api::V1::UsersController).
    unless real_current_user
      return render json: { error: "Authentication required" }, status: :unauthorized
    end
    return if real_current_user.admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  # A real round trip instead of `connection.active?`: in a freshly booted
  # process the pooled connection is created lazily, so `active?` reports
  # false until some other query has warmed it — which made a healthy
  # database report "error" (503) on the very first request.
  def database_connected?
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.select_value("SELECT 1")
    end
    true
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
