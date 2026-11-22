# Analytics beacon rate limiting (Phase 4 contract).
# 300 req/min per IP, 60 req/min per visitor UUID. Returns 429 when exceeded.
#
# Throttles are NOT registered in the test environment: request specs share one
# process (and one 127.0.0.1 IP), so production limits — especially the tight
# trade-submission intake (10/hour) — would 429 legitimate spec traffic and
# cascade nil-package failures through the Trade suite. Abuse protection is
# exercised in its own focused specs by stubbing the throttle store.
class Rack::Attack
  unless Rails.env.test?
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

    throttle("invitations/public/ip", limit: 30, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/api/v1/invitations/") && req.post?
    end

    # ---- Public contact form (IDENTITY_209) ---------------------------------
    # Two windows: a short burst guard plus a daily cap. Both are per IP; a
    # shared office/NAT address is expected to stay well under these limits.
    throttle("contact_messages/ip/burst", limit: 5, period: 10.minutes) do |req|
      req.ip if req.path == "/api/v1/contact_messages" && req.post?
    end

    throttle("contact_messages/ip/daily", limit: 20, period: 1.day) do |req|
      req.ip if req.path == "/api/v1/contact_messages" && req.post?
    end

    # ---- Trade portal (IDENTITY_206) ----------------------------------------
    # Public intake is the most-abused surface: tight per-IP limits on
    # submission creation, and looser read limits on guest access (a legitimate
    # winery office may share one NAT IP — §10.5 of the trade plan).
    throttle("trade/submissions/ip", limit: 10, period: 1.hour) do |req|
      req.ip if req.path == "/api/v1/trade/submissions" && req.post?
    end

    throttle("trade/guest_read/ip", limit: 60, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/api/v1/trade/guest_packages/")
    end

    throttle("trade/messages/ip", limit: 30, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{/api/v1/trade/packages/\d+/messages\z}) && req.post?
    end

    throttle("trade/checkout/ip", limit: 10, period: 1.minute) do |req|
      req.ip if req.path.match?(%r{/api/v1/trade/invoices/\d+/checkout\z}) && req.post?
    end

    # ---- Authentication brute-force guard (security audit issue #23) --------
    # Per-IP throttle on the credential endpoints. The JSON body is not parsed
    # into req.params, so a reliable per-email key is not available here; the
    # per-IP window plus Devise's own password verification is the control.
    throttle("auth/sign_in/ip", limit: 10, period: 1.minute) do |req|
      req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
    end

    throttle("auth/sign_up/ip", limit: 10, period: 1.minute) do |req|
      req.ip if req.path == "/api/v1/auth/sign_up" && req.post?
    end

    # Cache store defaults to memory; Solid Cache (SQL-backed) works too.
    # Configure explicitly so throttles share state across processes.
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end
end

# Wire Rack::Attack into the middleware stack (production-style envs only).
Rails.application.config.middleware.use Rack::Attack unless Rails.env.test? || Rails.env.development?
