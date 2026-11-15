module Trade
  # Editorial assessment (IDENTITY_206 Phase 7): applies per-wine decisions and
  # drives the package through the editorial chain.
  #
  # decisions: { item_id => "approved" | "rejected" | "information_requested" }
  #            (information_requested carries an optional per-item note)
  #
  # Guarantees:
  #   * every item must receive exactly one decision;
  #   * decisions, item statuses and the package transition land in ONE
  #     transaction — a failure rolls everything back;
  #   * original submission snapshots are never touched (immutable by design);
  #   * each decision is audited via WinePackageEvent (internal visibility).
  class Assessment
    DECISIONS = %w[approved rejected information_requested].freeze

    def self.call(package, editor:, decisions:, reason: nil)
      new(package, editor: editor, decisions: decisions, reason: reason).call
    end

    def initialize(package, editor:, decisions:, reason: nil)
      @package = package
      @editor = editor
      @decisions = normalize_decisions(decisions)
      @reason = reason
    end

    def call
      raise Error, "only a trade submission in editorial assessment can be assessed" unless
        package.trade_submission? && package.status.in?(%w[editorial_pending partially_approved])

      missing = item_ids - decisions.keys.map(&:to_i)
      raise Error, "every wine needs a decision" if missing.any?

      unknown = decisions.keys.map(&:to_i) - item_ids
      raise Error, "decision for an unknown wine" if unknown.any?

      bad = decisions.find { |_, d| DECISIONS.exclude?(d) }
      raise Error, "unknown decision #{bad[1].inspect}" if bad

      ActiveRecord::Base.transaction do
        package.begin_assessment!(actor: editor) if package.editorial_pending?

        decisions.each do |item_id, decision|
          item = package.items.find(item_id)
          note = decision == "information_requested" ? decision_notes[item_id] : nil
          item.update!(item_status: decision, received_notes: note.presence || item.received_notes)
          package.wine_package_events.create!(
            event_type: "editorial_assessment",
            actor: editor,
            visibility: "internal",
            occurred_at: Time.current,
            metadata: { wine_package_item_id: item.id, decision: decision, note: note }
          )
        end

        package.rejection_reason = reason if reason.present?
        package.record_assessment!(actor: editor)
      end
      package
    end

    private

    attr_reader :package, :editor, :decisions, :reason

    def item_ids
      @item_ids ||= package.items.ids
    end

    # decisions may be given as { "12" => "approved" } or
    # { "12" => { "decision" => "information_requested", "note" => "..." } } —
    # normalised to { item_id => decision } with notes kept separately.
    # Controller params arrive as ActionController::Parameters; convert to a
    # plain hash first or #each_with_object raises NoMethodError.
    def normalize_decisions(raw)
      raw_hash =
        if raw.is_a?(ActionController::Parameters)
          raw.to_unsafe_h
        else
          raw || {}
        end

      raw_hash.each_with_object({}) do |(id, value), memo|
        if value.is_a?(Hash)
          memo[id.to_i] = value["decision"] || value[:decision]
          @notes ||= {}
          @notes[id.to_i] = value["note"] || value[:note]
        else
          memo[id.to_i] = value
        end
      end
    end

    def decision_notes
      @notes ||= {}
    end
  end
end