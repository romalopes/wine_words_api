# Validated reporting query parameters (Phase 6).
#
# Allowlist-and-cap boundary for every reporting input. Returns plain Ruby
# values — never SQL fragments, never interpolated strings — so Phase 7
# services can consume them without further parsing.
#
# Returns [params, nil] on success or [nil, error_symbol] on invalid input.
# Errors use the existing Api::V1 controllers' `{ error: }` payload and map
# to 422, matching the analytics ingestion endpoint's validation style.
module Analytics
  class ReportingParams
    CONTENT_TYPES = %w[Article Review Wine all].freeze
    SORTS = %w[views unique_viewers likes comments engagement_rate published_at].freeze
    DIRECTIONS = %w[asc desc].freeze
    GROUPINGS = %w[day week none].freeze

    def self.resolve(params, max_per_page: nil)
      max_per_page ||= Rails.application.config.analytics[:max_per_page]
      new(params, max_per_page: max_per_page).resolve
    end

    def initialize(params, max_per_page:)
      @params = params
      @max_per_page = max_per_page
    end

    def resolve
      type = param_value(:content_type, default: "all")
      return [ nil, :invalid_content_type ] unless CONTENT_TYPES.include?(type.to_s)

      sort = param_value(:sort, default: "views")
      return [ nil, :invalid_sort ] unless SORTS.include?(sort.to_s)

      direction = param_value(:direction, default: "desc")
      return [ nil, :invalid_direction ] unless DIRECTIONS.include?(direction.to_s)

      grouping = param_value(:grouping, default: "none")
      return [ nil, :invalid_grouping ] unless GROUPINGS.include?(grouping.to_s)

      page_error, page = parse_page
      return [ nil, page_error ] if page_error

      per_page_error, per_page = parse_per_page
      return [ nil, per_page_error ] if per_page_error

      author_error, author_id = parse_author_id
      return [ nil, author_error ] if author_error

      instance = self.class.new(
        content_type: type.to_s, sort: sort.to_s, direction: direction.to_s,
        grouping: grouping.to_s, page: page, per_page: per_page,
        author_id: author_id
      )
      [ instance, nil ]
    end

    private

    def param_value(key, default:)
      value = @params[key].presence || @params[key.to_s].presence
      value.nil? ? default : value
    end

    def parse_page
      raw = @params[:page].presence || @params["page"].presence
      return [ nil, 1 ] if raw.nil?

      page = Integer(raw.to_s, 10)
      return [ :invalid_pagination, nil ] if page < 1 || page > 10_000

      [ nil, page ]
    rescue ArgumentError, TypeError
      [ :invalid_pagination, nil ]
    end

    def parse_per_page
      raw = @params[:per_page].presence || @params["per_page"].presence
      return [ nil, Rails.application.config.analytics[:default_per_page] ] if raw.nil?

      per_page = Integer(raw.to_s, 10)
      return [ :invalid_pagination, nil ] if per_page < 1 || per_page > @max_per_page

      [ nil, per_page ]
    rescue ArgumentError, TypeError
      [ :invalid_pagination, nil ]
    end

    # Author filter is an ownership hint only. Scope re-validates it against
    # the requester's role matrix (see Analytics::Scope#apply_author_filter):
    # a Reviewer may only ever see their own id, so a forged filter cannot
    # disclose another author's aggregates.
    def parse_author_id
      raw = @params[:author_id].presence || @params["author_id"].presence
      return [ nil, nil ] if raw.nil?

      author_id = Integer(raw.to_s, 10)
      return [ :invalid_author_id, nil ] unless author_id.positive?

      [ nil, author_id ]
    rescue ArgumentError, TypeError
      [ :invalid_author_id, nil ]
    end

    attr_reader :content_type, :sort, :direction, :grouping,
                :page, :per_page, :author_id

    def initialize(attrs)
      @content_type = attrs[:content_type]
      @sort = attrs[:sort]
      @direction = attrs[:direction]
      @grouping = attrs[:grouping]
      @page = attrs[:page]
      @per_page = attrs[:per_page]
      @author_id = attrs[:author_id]
    end

    def pagination
      { page: page, per_page: per_page }
    end

    def offset
      (page - 1) * per_page
    end
  end
end
