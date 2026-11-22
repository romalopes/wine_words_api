module WinePackages
  # Aggregates invoice data for a single WinePackage into a billing summary.
  #
  # Used by serializers and staff API to expose:
  # - total bottles submitted
  # - total billable to date
  # - total invoiced / paid / outstanding
  # - derived payment state
  # - overdue flag
  # - invoice history
  class BillingSummary
    attr_reader :wine_package

    def initialize(wine_package)
      @wine_package = wine_package
    end

    # All non-draft invoices for this package.
    def invoices
      @invoices ||= wine_package.wine_package_invoices.where.not(status: :draft).order(:created_at)
    end

    # All manual (review-fee) invoices.
    def manual_invoices
      invoices.manual
    end

    # Total bottles submitted (estimate snapshot or live count).
    def bottles_submitted
      wine_package.estimated_bottle_count || wine_package.submitted_bottle_count
    end

    # Total billable bottles confirmed by staff.
    def billable_to_date
      wine_package.billable_bottle_count || 0
    end

    # Sum of totals for all non-draft manual invoices.
    def total_invoiced
      manual_invoices.sum(:total).to_d
    end

    # Sum of totals for paid manual invoices.
    def total_paid
      manual_invoices.paid.sum(:total).to_d
    end

    # Sum of totals for cancelled manual invoices.
    def total_cancelled
      manual_invoices.cancelled.sum(:total).to_d
    end

    # Outstanding = sent invoices not paid.
    def outstanding
      manual_invoices.where(status: :sent).sum(:total).to_d
    end

    # Derived payment state.
    # :not_invoiced, :invoiced, :partially_paid, :settled
    def payment_state
      return :not_invoiced if manual_invoices.where(status: :sent).none?
      return :settled if outstanding.zero?
      return :partially_paid if total_paid.positive?

      :invoiced
    end

    # True if any sent manual invoice is past due.
    def overdue?
      manual_invoices.where(status: :sent).where("due_at < ?", Time.current).exists?
    end

    # Hash suitable for JSON serialization.
    def to_h
      money = ->(value) { format("%.2f", value) }
      {
        bottles_submitted: bottles_submitted,
        billable_to_date: billable_to_date,
        total_invoiced: money.call(total_invoiced),
        total_paid: money.call(total_paid),
        total_cancelled: money.call(total_cancelled),
        outstanding: money.call(outstanding),
        payment_state: payment_state.to_s,
        overdue: overdue?,
        invoices: manual_invoices.map do |inv|
          {
            id: inv.id,
            invoice_number: inv.invoice_number,
            status: inv.status,
            payment_source: inv.payment_source,
            billable_bottle_count: inv.billable_bottle_count,
            unit_fee: inv.unit_fee && money.call(inv.unit_fee),
            currency: inv.currency,
            subtotal: money.call(inv.subtotal),
            tax: money.call(inv.tax),
            total: money.call(inv.total),
            issued_at: inv.issued_at&.iso8601,
            due_at: inv.due_at&.iso8601,
            paid_at: inv.paid_at&.iso8601,
            recorded_by_id: inv.recorded_by_id,
            recorded_at: inv.recorded_at&.iso8601,
            cancellation_reason: inv.cancellation_reason,
            notes: inv.notes,
            overdue: inv.overdue_for_display?,
            email_sent_at: inv.email_sent_at&.iso8601,
            email_send_count: inv.email_send_count,
            reminder_sent_at: inv.reminder_sent_at&.iso8601
          }
        end
      }
    end
  end
end