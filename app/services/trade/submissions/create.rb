module Trade
  module Submissions
    # Creates a WinePackage from the PUBLIC multi-step submission form
    # (IDENTITY_206 Phase 3) — no authentication, no Producer, no User.
    #
    # Contract:
    #   * `contact_snapshot` is stored verbatim (JSONB) and validated by the
    #     WinePackage model (company_name, contact_name, email required).
    #   * Every wine becomes a WinePackageItem with immutable snapshot_* fields;
    #     NO catalogue Wine/Vintage is created and NO Producer is matched.
    #   * The package is created directly in `editorial_pending` with source
    #     `trade_submission`; the `trade_submitted` timeline event is recorded
    #     in the same transaction.
    #   * A single-use guest token (hashed) is generated so the anonymous
    #     submitter can follow the package (Phases 5/6).
    #   * `idempotency_key` (client-generated, DB-backed, no TTL) makes
    #     double-clicks and retries return the original package instead of
    #     creating a duplicate.
    #
    # Turnstile verification and rate limiting are applied in the controller
    # (see the separate infrastructure plan) BEFORE this service runs.
    class Create

      # Params shape (already strong-param-filtered by the controller):
      #   contact_snapshot: { company_name, contact_name, email, phone,
      #                       address, country, website, role, notes }
      #   wines: [{ wine_name, vintage, region, appellation, grape_varieties,
      #             abv, volume_ml, closure_type, tasting_notes,
      #             technical_sheet_url, trade_price, retail_price,
      #             sample_available, sample_quantity }]
      #   idempotency_key: String (optional but strongly recommended)
      def self.call(params, submitted_ip: nil, submitter: nil)
        new(params, submitted_ip: submitted_ip, submitter: submitter).call
      end

      def initialize(params, submitted_ip: nil, submitter: nil)
        # Request params arrive as string-keyed hashes (JSON/permit); the
        # service speaks symbols, so normalise once at the boundary.
        @params = params.deep_symbolize_keys
        @submitted_ip = submitted_ip
        @submitter = submitter
      end

      def call
        return replay_result if idempotent_replay?
        raise Error, "at least one wine is required" if wines.empty?

        package = nil
        guest_token = nil
        ActiveRecord::Base.transaction do
          package = WinePackage.new(
            source: "trade_submission",
            # editorial_pending is an ENTRY status for the trade chain (like
            # "arrived"/"requested" for the editorial/producer chains).
            status: "editorial_pending",
            contact_snapshot: params[:contact_snapshot],
            created_by: @submitter,
            submitter: @submitter
          )
          package.save!
          package.items.create!(wines.map { |wine| item_attributes(wine) })
          package.wine_package_events.create!(
            event_type: "trade_submitted",
            visibility: "shared",
            occurred_at: Time.current,
            metadata: submission_metadata
          )
          guest_token = package.generate_guest_token!
          store_idempotency!(package)
        end

        Result.new(package: package, guest_token: guest_token, replayed: false)
      rescue ActiveRecord::RecordInvalid => e
        raise Error, e.record.errors.full_messages.to_sentence
      end

      Result = Struct.new(:package, :guest_token, :replayed, keyword_init: true)

      private

      attr_reader :params, :submitted_ip

      # A replay returns the ORIGINAL package without a fresh guest token: the
      # client already holds the token from the first response, and re-issuing
      # one would rotate the digest and invalidate the link they have.
      def replay_result
        Result.new(package: existing, guest_token: nil, replayed: true)
      end

      def item_attributes(wine)
        vintage = wine[:vintage].to_s.strip
        # The picker offers "NV" (non vintage), "MV" (multi vintage) and
        # calendar years. NV/MV are stored as a label with a nil year; a
        # 4-digit year is stored as the integer year with no label.
        if %w[NV MV].include?(vintage.upcase)
          vintage_year = nil
          vintage_label = vintage.upcase
        else
          vintage_year = vintage.presence&.to_i
          vintage_label = nil
        end

        {
          proposed_wine_name: wine[:wine_name],
          quantity: wine[:quantity].presence || 1,
          proposed_vintage_year: vintage_year,
          snapshot_vintage_label: vintage_label,
          snapshot_region: wine[:region],
          snapshot_appellation: wine[:appellation],
          snapshot_grape_varieties: wine[:grape_varieties],
          snapshot_abv: wine[:abv],
          snapshot_volume_ml: wine[:volume_ml],
          snapshot_closure_type: wine[:closure_type],
          snapshot_tasting_notes: wine[:tasting_notes],
          snapshot_technical_sheet_url: wine[:technical_sheet_url],
          snapshot_trade_price: wine[:trade_price],
          snapshot_retail_price: wine[:retail_price],
          snapshot_sample_available: ActiveModel::Type::Boolean.new.cast(wine[:sample_available]) || false,
          snapshot_sample_quantity: wine[:sample_quantity],
          item_status: "pending"
        }
      end

      def wines
        Array(params[:wines])
      end

      def submission_metadata
        {
          wine_count: wines.size,
          submitted_ip_hash: submitted_ip ? Digest::SHA256.hexdigest(submitted_ip) : nil
          # NOTE: the Turnstile verification result is appended by the
          # controller once the separate infrastructure plan lands.
        }
      end

      # ---- Idempotency (DB-backed; survives restarts, works with any cache) ---

      def idempotent_replay?
        idempotency_key.present? && existing.present?
      end

      def existing
        @existing ||= begin
          return nil if idempotency_key.blank?

          TradeIdempotencyKey.find_by(key_digest: key_digest)&.wine_package
        end
      end

      def store_idempotency!(package)
        return if idempotency_key.blank?

        TradeIdempotencyKey.create!(wine_package: package, key_digest: key_digest)
      rescue ActiveRecord::RecordNotUnique
        # A concurrent request stored the same key first; the replay path
        # resolves it on the next attempt. The current package stands.
        nil
      end

      def key_digest
        Digest::SHA256.hexdigest(idempotency_key)
      end

      def idempotency_key
        params[:idempotency_key].presence
      end
    end
  end
end