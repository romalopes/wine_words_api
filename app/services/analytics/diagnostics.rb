# Admin-only diagnostics for analytics events (Phase 11).
#
# Provides bounded, paginated inspection of accepted events and aggregate
# exclusion reasons. All identity data is masked; no raw IPs, tokens, names,
# full user agents, or rejected events are ever exposed.
module Analytics
  class Diagnostics
    MAX_PER_PAGE = 50
    DEFAULT_PER_PAGE = 25

    # Returns paginated accepted events with masked identities.
    #
    # @param params [Hash] :page, :per_page, :content_type, :viewable_id, :start_date, :end_date
    # @return [Hash] { events: [...], pagination: {...}, scope_label: "..." }
    def self.accepted_events(params)
      page = [params[:page].to_i, 1].max
      per_page = params[:per_page].present? ? [[params[:per_page].to_i, 1].max, MAX_PER_PAGE].min : DEFAULT_PER_PAGE

      scope = Event.accepted.order(viewed_at: :desc)

      # Optional filters
      scope = scope.where(viewable_type: params[:content_type]) if params[:content_type].present?
      scope = scope.where(viewable_id: params[:viewable_id]) if params[:viewable_id].present?
      if params[:start_date].present? && params[:end_date].present?
        start_dt = Time.iso8601(params[:start_date]) rescue nil
        end_dt = Time.iso8601(params[:end_date]) rescue nil
        if start_dt && end_dt
          # Include the entire end second by adding 1 second and using exclusive upper bound
          scope = scope.where(viewed_at: start_dt..(end_dt + 1.second))
        end
      end

      total_count = scope.count
      total_pages = (total_count.to_f / per_page).ceil
      total_pages = 1 if total_pages.zero?

      events = scope.limit(per_page).offset((page - 1) * per_page).pluck(
        :id, :viewable_type, :viewable_id, :identity, :viewed_at,
        :source, :referrer, :viewport, :visitor_key, :created_at
      )

      {
        events: events.map { |e| mask_event(e) },
        pagination: {
          page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: total_pages
        },
        scope_label: "Accepted events (masked)"
      }
    end

    # Returns aggregate counts of exclusion reasons for rejected events.
    #
    # Since rejection happens at ingestion (dedup, opt-out, invalid), we
    # approximate by counting accepted=false events. In future phases this
    # could be enhanced with explicit rejection reason columns.
    #
    # @param params [Hash] :start_date, :end_date
    # @return [Hash] { exclusion_reasons: {...}, scope_label: "..." }
    def self.exclusion_reasons(params)
      scope = Event.rejected
      if params[:start_date].present? && params[:end_date].present?
        start_dt = Time.iso8601(params[:start_date]) rescue nil
        end_dt = Time.iso8601(params[:end_date]) rescue nil
        if start_dt && end_dt
          # Include the entire end second by adding 1 second and using exclusive upper bound
          scope = scope.where(viewed_at: start_dt..(end_dt + 1.second))
        end
      end

      # Current schema only has accepted boolean; detailed reasons not persisted.
      # This is a placeholder for future enhancement with rejection_reason column.
      {
        exclusion_reasons: {
          total_rejected: scope.count,
          note: "Detailed rejection reasons not yet persisted; all rejections are aggregated. See ADR-010 for future enhancement."
        },
        scope_label: "Exclusion reasons (aggregated)"
      }
    end

    private

    # Mask identity and sensitive fields for diagnostic output.
    def self.mask_event(row)
      id, viewable_type, viewable_id, identity, viewed_at, source, referrer, viewport, visitor_key, created_at = row

      # Mask identity: account:123 -> "account:***", visitor:uuid -> "visitor:***"
      masked_identity = if identity.start_with?("account:")
        "account:***"
      elsif identity.start_with?("visitor:")
        "visitor:***"
      else
        "***"
      end

      # Mask referrer (strip query params, keep origin only)
      masked_referrer = mask_referrer(referrer)

      # Mask visitor_key (show first 8 chars only)
      masked_visitor_key = visitor_key ? "#{visitor_key[0, 8]}..." : nil

      # Viewport is safe to show as-is (e.g., "1920x1080")
      # Source is safe (e.g., "direct", "navigation", "search")

      {
        id: id,
        viewable_type: viewable_type,
        viewable_id: viewable_id,
        identity: masked_identity,
        viewed_at: viewed_at,
        source: source,
        referrer: masked_referrer,
        viewport: viewport,
        visitor_key: masked_visitor_key,
        created_at: created_at
      }
    end

    def self.mask_referrer(referrer)
      return nil if referrer.blank?

      uri = URI.parse(referrer) rescue nil
      return "[malformed]" unless uri

      "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port != uri.default_port}"
    rescue
      "[malformed]"
    end
  end
end