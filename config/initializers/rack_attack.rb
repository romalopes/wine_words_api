# Analytics beacon rate limiting (Phase 4 contract).
# 300 req/min per IP, 60 req/min per visitor UUID. Returns 429 when exceeded.
class Rack::Attack
  throttle("analytics/views/ip", limit: 300, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/analytics/views" && req.post?
  end

  throttle("analytics/events/ip", limit: 300, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/analytics/events" && req.post?
  end

  throttle("analytics/views/visitor", limit: 60, period: 1.minute) do |req|
    if (req.path == "/api/v1/analytics/views" || req.path == "/api/v1/analytics/events") && req.post?
      req.env["HTTP_X_VISITOR_ID"].presence || req.ip
    end
  end

  # Cache store defaults to memory; Solid Cache (SQL-backed) works too.
  # Configure explicitly so throttles share state across processes.
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end

# Wire Rack::Attack into the middleware stack.
Rails.application.config.middleware.use Rack::Attack
