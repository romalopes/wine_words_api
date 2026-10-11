# Analytics reporting periods (Phase 6).
#
# Converts approved period tokens (`7d`, `30d`, `90d`, `1y`, `all`) or custom
# Australia/Sydney calendar dates into a validated UTC [start_at, end_at)
# half-open interval. All timestamps are TimeWithZone in UTC; the reporting
# timezone is metadata only.
#
# Boundary contract (per the metric dictionary):
# - `start_at` is inclusive, `end_at` is exclusive — adjacent periods never
#   overlap and no event is double-counted.
# - Token periods are day-aligned in the reporting timezone ("today" means
#   the full Sydney calendar day), so DST transitions stay correct: the
#   interval is built from timezone-local midnights, not 24h multiples.
# - Custom ranges are Sydney calendar dates converted to UTC; a missing
#   `start_date` means "from available history".
#
# `clamp_to_history` intersects the requested range with the queryable
# history window (retention cap → earliest accepted event). When the
# requested range starts after history ends, `empty?` is true and consumers
# must return zeros with partial/false coverage metadata instead of querying.
module Analytics
  class Period
    REPORTING_TIMEZONE = "Australia/Sydney".freeze

    # Approved period tokens for V1 reporting.
    PERIOD_TOKENS = %w[7d 30d 90d 1y all].freeze

    # Token → number of Sydney calendar days (nil = unbounded).
    TOKEN_DAYS = {
      "7d" => 7,
      "30d" => 30,
      "90d" => 90,
      "1y" => 365,
      "all" => nil,
    }.freeze

    # Metric definition version stamped on every reporting response.
    METRIC_VERSION = "v1".freeze

    # Error symbols returned by `.resolve` instead of raising, so controllers
    # can map them to 422 without leaking internals.
    INVALID_PERIOD = :invalid_period
    INVALID_DATE_RANGE = :invalid_date_range
    RANGE_TOO_LONG = :range_too_long

    attr_reader :token, :requested_start_at, :requested_end_at,
                :start_at, :end_at, :timezone,
                :available_from, :available_to,
                :partial_history, :available_history

    # Resolves a period from query params.
    #
    # params - hash with optional "period" token and/or "start_date"/"end_date"
    #          (ISO "YYYY-MM-DD", interpreted in Australia/Sydney).
    # now: reference time used as "today" (default: Time.current).
    # max_range_days: cap for custom ranges (from Analytics config).
    # history_from/history_to: queryable history window; nil history_from
    #          means no accepted events exist yet.
    #
    # Returns [period, nil] on success or [nil, error_symbol] on invalid input.
    def self.resolve(params, now: Time.current, max_range_days: nil, history_from: nil, history_to: nil)
      max_range_days ||= Rails.application.config.analytics[:max_custom_range_days]
      new(params, now: now, max_range_days: max_range_days,
                  history_from: history_from, history_to: history_to).resolve
    end

    def initialize(params, now:, max_range_days:, history_from:, history_to:)
      @params = params
      @now = now
      @max_range_days = max_range_days
      @available_from = history_from
      @available_to = history_to
      @timezone = REPORTING_TIMEZONE
    end

    def resolve
      token_error = resolve_token
      return [ nil, token_error ] if token_error

      date_error = resolve_dates
      return [ nil, date_error ] if date_error

      clamp_to_history
      [ self, nil ]
    end

    # True when the effective range has zero width (requested range starts at
    # or after history ends). Consumers must report zeros with coverage
    # metadata rather than issuing aggregate queries.
    def empty?
      start_at >= end_at
    end

    # Number of Sydney calendar days covered by the requested window, or nil
    # when the window is open-ended (`period=all` without a custom start).
    def days
      return nil if @sydney_start.nil?

      ((@sydney_end - @sydney_start) / 1.day).to_i
    end

    def metadata
      {
        timezone: timezone,
        metric_version: METRIC_VERSION,
        period: token,
        start_at: start_at.iso8601,
        end_at: end_at.iso8601,
        available_from: available_from&.iso8601,
        available_to: available_to&.iso8601,
        partial_history: partial_history,
        available_history: available_history,
      }
    end

    private

    def resolve_token
      raw = @params[:period].presence || @params["period"].presence || "30d"
      @token = raw.to_s
      return INVALID_PERIOD unless PERIOD_TOKENS.include?(@token)

      @today = @now.in_time_zone(REPORTING_TIMEZONE).to_date
      @sydney_end = @today + 1 # exclusive: end of "today" in Sydney
      days_back = TOKEN_DAYS[@token]
      @sydney_start = days_back ? (@sydney_end - days_back) : nil
      nil
    end

    # Custom dates refine the token window; they can only narrow, never widen,
    # so `period=7d` with an older `start_date` still yields at most 7 days.
    def resolve_dates
      raw_start = @params[:start_date].presence || @params["start_date"].presence
      raw_end = @params[:end_date].presence || @params["end_date"].presence
      return nil if raw_start.blank? && raw_end.blank?

      begin
        custom_start = Date.iso8601(raw_start.to_s) if raw_start.present?
        custom_end = Date.iso8601(raw_end.to_s) if raw_end.present?
      rescue Date::Error, ArgumentError
        return INVALID_DATE_RANGE
      end

      if custom_start && custom_end && custom_end < custom_start
        return INVALID_DATE_RANGE
      end

      if custom_start && custom_end && (custom_end - custom_start).to_i + 1 > @max_range_days
        return RANGE_TOO_LONG
      end

      if custom_start && @sydney_start && custom_start < @sydney_start
        return INVALID_DATE_RANGE
      end
      if custom_end && custom_end >= @sydney_end
        return INVALID_DATE_RANGE
      end

      @sydney_start = custom_start if custom_start && (@sydney_start.nil? || custom_start > @sydney_start)
      @sydney_end = custom_end + 1 if custom_end
      nil
    end

    # Effective UTC boundaries from Sydney-local midnights. ActiveSupport
    # resolves each midnight through the zone's DST rules, so a 23h/25h
    # Sydney day maps to the correct UTC instant on both sides.
    def requested_range
      zone = ActiveSupport::TimeZone[REPORTING_TIMEZONE]
      from = @sydney_start ? zone.local(@sydney_start.year, @sydney_start.month, @sydney_start.day).utc : nil
      to = zone.local(@sydney_end.year, @sydney_end.month, @sydney_end.day).utc
      [ from, to ]
    end

    # Intersects the requested Sydney-day window with the queryable history
    # window. History bounds are UTC instants which may fall mid-Sydney-day;
    # the effective UTC boundaries are then raw instants, not midnights —
    # the half-open contract is what matters, not day alignment.
    def clamp_to_history
      requested_from, requested_to = requested_range
      @requested_start_at = requested_from
      @requested_end_at = requested_to

      @partial_history = false
      @available_history = true

      floor = @available_from
      ceiling = @available_to || @now.utc

      if floor.nil?
        # No accepted events yet: nothing is queryable.
        @available_history = false
        @partial_history = !requested_from.nil?
        @start_at = requested_to
        @end_at = requested_to
        return
      end

      effective_from = requested_from
      effective_to = requested_to

      if effective_from.nil? || effective_from < floor
        @partial_history = true
        effective_from = floor
      end
      effective_to = ceiling if effective_to > ceiling

      if effective_from >= effective_to
        @start_at = effective_to
        @end_at = effective_to
      else
        @start_at = effective_from
        @end_at = effective_to
      end
    end
  end
end
