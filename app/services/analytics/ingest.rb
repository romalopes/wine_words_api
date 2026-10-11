module Analytics
  class Ingest
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :event_type, :string      # "view" (V1 only)
    attribute :content_type, :string    # "Article", "Review", "Wine"
    attribute :content_id, :integer
    attribute :identity, :string        # "account:123" or "visitor:uuid"
    attribute :occurred_at, :datetime   # client time (logged only)
    attribute :source, :string          # "direct", "search", "internal", "external"
    attribute :referrer, :string
    attribute :viewport, :string
    attr_accessor :current_user # User or nil (not serializable as attribute)

    # Entry point: call from controller or job
    def self.call(**attrs)
      new(**attrs).call
    end

    def call
      return Result.failure(:invalid_event_type) unless event_type == "view"
      return Result.failure(:invalid_content_type) unless Analytics::Event::CONTENT_TYPES.include?(content_type)
      return Result.failure(:invalid_content_id) unless content_id&.positive?
      return Result.failure(:invalid_identity) unless identity&.match?(/\A(account:[0-9]+|visitor:[0-9a-f-]{36})\z/i)

      # Authorization/exclusion checks
      exclusion = check_exclusions
      return exclusion if exclusion

      viewed_at = Time.current
      lock_key = Analytics::Event.dedup_lock_key(content_type, content_id, identity, viewed_at)
      visitor_key = Analytics::Event.compute_visitor_key(content_type, content_id, identity, viewed_at)

      # Advisory lock deduplication with pre-check logic
      result = nil
      ActiveRecord::Base.transaction do
        # Set lock timeout
        ActiveRecord::Base.connection.execute("SET LOCAL lock_timeout = #{Rails.application.config.analytics[:lock_timeout_ms]}")
        ActiveRecord::Base.connection.execute("SET LOCAL statement_timeout = #{Rails.application.config.analytics[:statement_timeout_ms]}")

        # Acquire advisory lock
        acquired = ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_xact_lock(#{lock_key})")
        unless acquired
          Rails.logger.warn "[Analytics] Advisory lock contention for key #{lock_key}"
          return Result.success(duplicate: true, accepted: false, reason: :lock_contention)
        end

        # Check for existing accepted event within dedup window
        window_start = viewed_at - Rails.application.config.analytics[:dedup_window_seconds].seconds
        existing = Analytics::Event.accepted
                          .for_content(content_type, content_id)
                          .for_identity(identity)
                          .where(viewed_at: window_start..viewed_at)
                          .exists?

        if existing
          return Result.success(duplicate: true, accepted: false, reason: :deduplicated)
        end

        # Create the event
        event = Analytics::Event.create!(
          viewable_type: content_type,
          viewable_id: content_id,
          identity: identity,
          visitor_key: visitor_key,
          viewed_at: viewed_at,
          source: source,
          referrer: referrer,
          viewport: viewport,
          accepted: true
        )

        Result.success(duplicate: false, accepted: true, event: event)
      end
    rescue ActiveRecord::RecordNotUnique => e
      # Race condition - another transaction got there first
      if e.message.include?("idx_analytics_events_dedup")
        Result.success(duplicate: true, accepted: false, reason: :deduplicated)
      else
        raise
      end
    rescue ActiveRecord::StatementInvalid => e
      if e.message.include?("lock_timeout") || e.message.include?("statement_timeout")
        Rails.logger.warn "[Analytics] Lock/statement timeout: #{e.message}"
        Result.success(duplicate: false, accepted: false, reason: :timeout)
      else
        raise
      end
    end

    private

    def check_exclusions
      if identity&.start_with?("visitor:") && !Rails.application.config.analytics[:track_anonymous]
        return Result.failure(:anonymous_disallowed)
      end

      return nil unless current_user&.persisted?

      if Rails.application.config.analytics[:excluded_roles].include?("Admin") && current_user.admin?
        return Result.success(duplicate: false, accepted: false, reason: :excluded_role)
      end

      if current_user.author_of?(content_type, content_id)
        return Result.success(duplicate: false, accepted: false, reason: :excluded_author)
      end

      if current_user.analytics_opt_out?
        return Result.success(duplicate: false, accepted: false, reason: :opt_out)
      end

      unless content_accessible?(current_user)
        return Result.success(duplicate: false, accepted: false, reason: :inaccessible)
      end

      nil
    end

    def content_accessible?(user)
      id = content_id.to_i
      case content_type
      when "Article"
        Article.visible_to(user).exists?(id)
      when "Review"
        Review.visible_to(user).exists?(id)
      when "Wine"
        Wine.exists?(id)
      else
        false
      end
    rescue StandardError
      false
    end
    private :content_accessible?
    class Result
      attr_reader :accepted, :duplicate, :error_code, :event, :reason

      def self.success(duplicate:, accepted:, event: nil, reason: nil)
        r = allocate
        r.instance_variable_set(:@success, true)
        r.instance_variable_set(:@duplicate, duplicate)
        r.instance_variable_set(:@accepted, accepted)
        r.instance_variable_set(:@event, event)
        r.instance_variable_set(:@reason, reason)
        r
      end

      def self.failure(error_code)
        r = allocate
        r.instance_variable_set(:@success, false)
        r.instance_variable_set(:@duplicate, false)
        r.instance_variable_set(:@accepted, false)
        r.instance_variable_set(:@error_code, error_code)
        r
      end

      def initialize(success:, duplicate: false, accepted: false)
        @success = success
        @duplicate = duplicate
        @accepted = accepted
      end

      def success?
        @success
      end

      def duplicate?
        @duplicate
      end
    end
  end
end