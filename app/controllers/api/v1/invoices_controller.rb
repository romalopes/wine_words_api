# Staff-wide invoice listing (IDENTITY_214).
#
# A cross-package overview of every recorded invoice for Admins and Editors:
# client, the wine package it belongs to, status and delivery state. This
# index only READS — mutations (create, mark paid, cancel) and the per-invoice
# email/PDF actions stay on the nested wine-package endpoints, which this page
# reuses for its "Email" / "Download" buttons.
class Api::V1::InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalogue_manager!

  def index
    invoices = WinePackageInvoice
                 .includes(wine_package: [:producer, :submitter, :wine_package_items])
                 .where.not(status: :draft)
                 .filter_by(filter_params)
                 .order(created_at: :desc)

    render json: invoices.map { |invoice| invoice_row(invoice) }
  end

  private

  # Billing is editorial-only everywhere else (WinePackagePolicy#manage_billing?),
  # so the global overview keeps the same audience: Admins and Editors.
  def authorize_catalogue_manager!
    return if current_user&.catalogue_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def report
    unless current_user&.catalogue_manager?
      render json: { error: "Forbidden" }, status: :forbidden
      return
    end

    invoices = WinePackageInvoice
                 .includes(wine_package: [:producer, :submitter, :wine_package_items])
                 .where.not(status: :draft)
                 .filter_by(filter_params)
                 .order(created_at: :desc)

    pdf = InvoiceReportPdf.call(invoices: invoices, filters: filter_params)
    send_data pdf.render,
              filename: "invoices-report-#{Date.current}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  end

  def filter_params
    params.slice(:status, :email_sent, :start_date, :end_date, :payment_source, :overdue).transform_values do |v|
      v.is_a?(String) ? v.presence&.downcase : v
    end
  end

  def invoice_row(invoice)
    package = invoice.wine_package
    money = ->(value) { value.nil? ? nil : format("%.2f", value) }
    snapshot = package.contact_snapshot || {}

    {
      id: invoice.id,
      invoice_number: invoice.invoice_number,
      status: invoice.status,
      payment_source: invoice.payment_source,
      overdue: invoice.overdue_for_display?,
      billable_bottle_count: invoice.billable_bottle_count,
      unit_fee: money.call(invoice.unit_fee),
      currency: invoice.currency,
      subtotal: money.call(invoice.subtotal),
      tax: money.call(invoice.tax),
      total: money.call(invoice.total),
      issued_at: invoice.issued_at&.iso8601,
      due_at: invoice.due_at&.iso8601,
      paid_at: invoice.paid_at&.iso8601,
      email_sent_at: invoice.email_sent_at&.iso8601,
      email_send_count: invoice.email_send_count,
      client: {
        company_name: snapshot["company_name"] || package.producer&.name,
        contact_name: snapshot["contact_name"] || snapshot["company_name"] || package.producer&.name,
        email: snapshot["email"] || package.submitter&.email || package.producer&.users&.first&.email
      },
      wine_package: {
        id: package.id,
        status: package.status,
        source: package.source,
        producer_name: package.producer&.name,
        item_count: package.wine_package_items.size
      }
    }
  end
end
