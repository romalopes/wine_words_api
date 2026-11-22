# Wine Package Invoices API (IDENTITY_214).
#
# Nested under wine_packages — manual billing operations for staff.
# All actions require manage_billing? permission.
class Api::V1::WinePackageInvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_package
  before_action :set_invoice, only: [:mark_paid, :cancel, :generate_pdf, :send_email, :pdf]
  before_action :authorize_billing_manage

  # POST /api/v1/wine_packages/:wine_package_id/invoices
  # Records an externally-sent invoice.
  def create
    # Calculate amount from confirmed billable count and current fee
    unless @package.billable_confirmed?
      return render json: { error: "Billable bottle count must be confirmed first" },
                    status: :unprocessable_entity
    end

    # Calculate delta: new invoice covers billable_count - sum of prior manual invoices
    prior_total = @package.wine_package_invoices.manual.where.not(status: :draft).sum(:billable_bottle_count)
    delta = @package.billable_bottle_count - prior_total

    if delta <= 0
      return render json: { error: "No additional billable bottles to invoice" },
                    status: :unprocessable_entity
    end

    fee_amount = AppSetting.wine_review_fee_amount
    fee_currency = AppSetting.wine_review_fee_currency
    total = (fee_amount * delta).round(2)

    invoice = @package.wine_package_invoices.create!(
      wine_package_quote: nil,
      invoice_number: WinePackageInvoice.next_number,
      currency: fee_currency,
      items: [], # manual invoices don't use the items JSONB the same way
      subtotal: total,
      tax: 0,
      total: total,
      status: :sent,
      issued_at: Time.current,
      due_at: invoice_params[:due_at] || 30.days.from_now,
      payment_source: :manual,
      billable_bottle_count: delta,
      unit_fee: fee_amount,
      recorded_by: current_user,
      recorded_at: Time.current,
      notes: invoice_params[:notes]
    )

    @package.wine_package_events.create!(
      event_type: "invoice_recorded",
      actor: current_user,
      visibility: "shared",
      occurred_at: Time.current,
      metadata: {
        wine_package_invoice_id: invoice.id,
        invoice_number: invoice.invoice_number,
        billable_bottle_count: delta,
        unit_fee: fee_amount.to_s("F"),
        total: total.to_s("F"),
        payment_source: "manual"
      }
    )

    render json: serialize_invoice(invoice), status: :created
  end

  # GET /api/v1/wine_packages/:wine_package_id/invoices/:id/pdf
  # Download PDF (staff + owner with view_billing?)
  def pdf
    authorize_billing_view
    pdf_service = WinePackages::InvoicePdfService.call(@invoice)
    send_data pdf_service.render,
              filename: "invoice-#{@invoice.invoice_number}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  # POST /api/v1/wine_packages/:wine_package_id/invoices/:id/generate_pdf
  # Generate and return PDF binary (for preview)
  def generate_pdf
    pdf_service = WinePackages::InvoicePdfService.call(@invoice)
    send_data pdf_service.render,
              filename: "invoice-#{@invoice.invoice_number}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  # POST /api/v1/wine_packages/:wine_package_id/invoices/:id/send_email
  # Queue email with PDF attachment
  def send_email
    unless @invoice.sent? || @invoice.draft?
      return render json: { error: "Only sent or draft invoices can be emailed" },
                    status: :unprocessable_entity
    end

    # Queue background job
    InvoiceMailerJob.perform_later(@invoice.id, triggered_by_id: current_user.id)

    render json: {
      queued: true,
      message: "Invoice email queued for delivery"
    }
  end

  # POST /api/v1/wine_packages/:wine_package_id/invoices/:id/mark_paid
  def mark_paid
    unless @invoice.sent?
      return render json: { error: "Only sent invoices can be marked paid" },
                    status: :unprocessable_entity
    end

    @invoice.update!(status: :paid, paid_at: Time.current)

    @package.wine_package_events.create!(
      event_type: "invoice_marked_paid",
      actor: current_user,
      visibility: "shared",
      occurred_at: Time.current,
      metadata: { wine_package_invoice_id: @invoice.id, invoice_number: @invoice.invoice_number }
    )

    render json: serialize_invoice(@invoice)
  end

  # POST /api/v1/wine_packages/:wine_package_id/invoices/:id/cancel
  def cancel
    if @invoice.paid?
      return render json: { error: "Paid invoices cannot be cancelled" },
                    status: :unprocessable_entity
    end

    reason = invoice_params[:cancellation_reason]
    if reason.blank?
      return render json: { error: "Cancellation reason is required" },
                    status: :unprocessable_entity
    end

    @invoice.update!(status: :cancelled, cancellation_reason: reason)

    @package.wine_package_events.create!(
      event_type: "invoice_cancelled",
      actor: current_user,
      visibility: "shared",
      occurred_at: Time.current,
      metadata: {
        wine_package_invoice_id: @invoice.id,
        invoice_number: @invoice.invoice_number,
        cancellation_reason: reason
      }
    )

    render json: serialize_invoice(@invoice)
  end

  private

  def set_package
    @package = WinePackage.find(params[:wine_package_id])
  end

  def set_invoice
    @invoice = @package.wine_package_invoices.find(params[:id])
  end

  def authorize_billing_manage
    policy = WinePackagePolicy.new(current_user, @package)
    unless policy.manage_billing?
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end

  def authorize_billing_view
    policy = WinePackagePolicy.new(current_user, @package)
    unless policy.view_billing?
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end

  def invoice_params
    params.permit(:due_at, :cancellation_reason, :notes)
  end

  def serialize_invoice(inv)
    money = ->(value) { format("%.2f", value) }
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
end