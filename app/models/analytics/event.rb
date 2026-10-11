module Analytics
  class Event < ApplicationRecord
    self.table_name = "analytics_events"

    # Allowlisted content types — mirrors Comment::COMMENTABLE_TYPES
    CONTENT_TYPES = %w[Article Review Wine].freeze

    # Identity prefixes (Phase 1 contract)
    ACCOUNT_PREFIX = "account:".freeze
    VISITOR_PREFIX = "visitor:".freeze
    ERASURE_PREFIX = "erased-".freeze

    # Validations
    validates :viewable_type, presence: true, inclusion: { in: CONTENT_TYPES }
    validates :viewable_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
    validates :identity, presence: true, format: { with: /\A(account:[0-9]+|visitor:([0-9a-f-]{36}|erased-[0-9a-f-]+))\z/i }
    validates :viewed_at, presence: true
    validates :source, length: { maximum: 32 }, allow_nil: true
    validates :referrer, length: { maximum: 500 }, allow_nil: true
    validates :viewport, length: { maximum: 32 }, allow_nil: true

    # Polymorphic accessor for viewable
    belongs_to :viewable, polymorphic: true, optional: true

    # Scopes
    scope :accepted, -> { where(accepted: true) }
    scope :rejected, -> { where(accepted: false) }
    scope :for_content, ->(type, id) { where(viewable_type: type, viewable_id: id) }
    scope :for_identity, ->(identity) { where(identity: identity) }
    scope :in_window, ->(start_at, end_at) { where(viewed_at: start_at...end_at) }
    scope :by_account, ->(account_id) { where(identity: "#{ACCOUNT_PREFIX}#{account_id}") }
    scope :by_visitor, ->(visitor_id) { where(identity: "#{VISITOR_PREFIX}#{visitor_id}") }

    # Class methods for lifecycle (Phase 2 contract)

    # Account erasure: anonymize identity while preserving aggregates
    def self.anonymize_account!(account_id)
      where(identity: "#{ACCOUNT_PREFIX}#{account_id}")
        .update_all("identity = '#{VISITOR_PREFIX}#{ERASURE_PREFIX}#{account_id}'")
    end

    # Visitor erasure on request
    def self.anonymize_visitor!(visitor_id)
      where(identity: "#{VISITOR_PREFIX}#{visitor_id}")
        .update_all("identity = '#{VISITOR_PREFIX}#{ERASURE_PREFIX}#{visitor_id}'")
    end

    # Hard delete for content destruction (GDPR Art. 17 / business requirement)
    def self.purge_content!(type, id)
      for_content(type, id).delete_all
    end

    # Soft archive for content archival (preserve for rollups)
    def self.archive_content!(type, id)
      for_content(type, id).update_all(accepted: false)
    end

    # Build identity string from current_user and visitor_id
    def self.build_identity(current_user, visitor_id)
      if current_user&.persisted? && !current_user.analytics_opt_out?
        "#{ACCOUNT_PREFIX}#{current_user.id}"
      else
        "#{VISITOR_PREFIX}#{visitor_id}"
      end
    end

    # Deduplication lock key (Phase 3)
    def self.dedup_lock_key(content_type, content_id, identity, viewed_at)
      digest = Digest::SHA256.hexdigest("view#{content_type}#{content_id}#{identity}#{viewed_at.to_date}")
      digest[0, 16].to_i(16) & 0x7fffffffffffffff # clamp to signed 63 bits
    end

    # Compute visitor_key from request components (for audit/debug)
    def self.compute_visitor_key(content_type, content_id, identity, viewed_at)
      Digest::SHA256.hexdigest("#{content_type}:#{content_id}:#{identity}:#{viewed_at.to_date}")[0, 32]
    end
  end
end