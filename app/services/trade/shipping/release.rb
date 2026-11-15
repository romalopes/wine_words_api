module Trade
  module Shipping
    # Payment-gated release of shipping instructions (IDENTITY_206 Phase 12).
    #
    # The gate is satisfied when
    #   * the package has a settled (paid) invoice, OR
    #   * an Admin records an explicit override (reason required) — audited on
    #     the package row itself via shipping_override_*.
    class Release
      def self.call(package, by:, override: false, reason: nil)
        new(package, by: by, override: override, reason: reason).call
      end

      def initialize(package, by:, override:, reason: nil)
        @package = package
        @by = by
        @override = override
        @reason = reason
      end

      def call
        # Validate the override FIRST: an Admin override waives the payment
        # gate by definition, so the gate must not be consulted (or refused)
        # before the override is authorised.
        if override
          raise Error, "an override reason is required" if reason.blank?
          raise Error, "only an Admin may override the payment gate" unless by&.admin?
        else
          raise Error, "only a paid trade package can be released for shipping" unless gate_open?
        end

        ActiveRecord::Base.transaction do
          package.release_shipping!(by: by, override: override, reason: reason)
          package.wine_package_events.create!(
            event_type: "shipping_released",
            actor: by,
            visibility: "shared",
            occurred_at: Time.current,
            metadata: { override: override, override_reason: override ? reason : nil }
          )
        end
        package
      end

      private

      attr_reader :package, :by, :override, :reason

      def gate_open?
        return false unless package.trade_submission?
        return true if package.shipping_override_at.present?

        package.wine_package_invoices.exists?(status: "paid")
      end
    end
  end
end