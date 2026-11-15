module Trade
  module Receipts
    # Records the physical receipt of one wine line (IDENTITY_206 Phase 12).
    #
    # `condition` and `received_at` are pre-existing WinePackageItem columns;
    # this service stamps them, moves the item to `received` (or keeps it
    # consistent for damaged/missing samples) and audits the outcome. Package
    # completion keeps using the existing WinePackages::CheckCompletion.
    class Record
      CONDITIONS = %w[good damaged missing].freeze

      def self.call(item, by:, condition: "good", notes: nil)
        new(item, by: by, condition: condition, notes: notes).call
      end

      def initialize(item, by:, condition: "good", notes: nil)
        @item = item
        @by = by
        @condition = condition
        @notes = notes
      end

      def call
        raise Error, "unknown receipt condition" unless CONDITIONS.include?(condition)
        raise Error, "only shipping-released trade items can be received" unless
          item.wine_package.trade_submission? &&
          item.wine_package.status.in?(%w[shipping_released in_transit arrived])

        ActiveRecord::Base.transaction do
          item.update!(
            condition: condition,
            received_at: Time.current,
            received_notes: notes,
            item_status: condition == "good" ? "received" : item.item_status
          )
          item.wine_package.wine_package_events.create!(
            event_type: "item_received",
            actor: by,
            visibility: "internal",
            occurred_at: Time.current,
            metadata: {
              wine_package_item_id: item.id,
              condition: condition,
              notes: notes
            }
          )
        end
        item
      end

      private

      attr_reader :item, :by, :condition, :notes
    end
  end
end