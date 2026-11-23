# Invoice Report PDF Generator (IDENTITY_214 Phase 6)
# Generates a PDF report of filtered invoices with summary totals.
# Uses Prawn::View with the same logo/header style as InvoicePdfService.
class WinePackages::InvoiceReportPdf
  extend Prawn::View

  HEADER_IMAGE = "app/assets/images/invoice-logo.png".freeze

  def self.call(invoices:, filters:)
    new(invoices: invoices, filters: filters).render
  end

  def initialize(invoices:, filters:)
    @invoices = invoices
    @filters = filters
  end

  def render
    Prawn.generate(pdf_options) do |pdf|
      draw_header(pdf)
      draw_title(pdf)
      draw_filter_summary(pdf)
      draw_table(pdf)
      draw_totals_row(pdf)
      draw_footer(pdf)
    end
  end

  private

  def pdf_options
    {
      page_size: "A4",
      margin: [40, 40, 40, 60],
      info: {
        Title: "Invoice Report",
        Producer: "Wine Words",
        Author: "Wine Words Admin"
      }
    }
  end

  def draw_header(pdf)
    # Draw logo/header section
    if File.exist?(Rails.root.join(HEADER_IMAGE))
      pdf.image Rails.root.join(HEADER_IMAGE), width: 120, height: 40, at: [40, pdf.bounds.top - 20]
    end

    pdf.fill_color "4a1020"
    pdf.fill_rect [0, pdf.bounds.top], pdf.bounds.width, 30
    pdf.fill_color "ffffff"
    pdf.draw_text "Invoice Report", size: 20, at: [40, pdf.bounds.top - 35]
    pdf.fill_color "4a1020"
  end

  def draw_title(pdf)
    pdf.move_down 20
    pdf.draw_text "Invoice report", size: 16, style: :bold, at: [40, pdf.bounds.top]
    pdf.move_down 10
  end

  def draw_filter_summary(pdf)
    return if @invoices.empty? && @filters.values.all? { |v| v.blank? || v == "all" }

    pdf.move_down 5
    pdf.fill_color "27615e"
    pdf.fill_rect [40, pdf.bounds.top], pdf.bounds.width - 80, 20
    pdf.fill_color "ffffff"

    filter_descriptions = {
      status: filter_status_description,
      email_sent: filter_email_description,
      start_date: -> { "From: #{format_date(@filters[:start_date])}" },
      end_date: -> { "To: #{format_date(@filters[:end_date])}" },
      payment_source: filter_payment_source_description,
      overdue: filter_overdue_description
    }

    active_filters = filter_descriptions.select { |_, desc| desc.call.present? }
    return if active_filters.empty?

    y_position = pdf.bounds.top - 35
    active_filters.each do |key, desc|
      pdf.draw_text desc.call, size: 9, at: [40, y_position]
      y_position -= 15
    end
    pdf.fill_color "4a1020"
  end

  def draw_table(pdf)
    return if @invoices.empty?

    column_widths = [ 70, 25, 100, 50, 35, 60, 40, 30 ]
    table_data = []

    # Header row
    table_data << [
      "Issued",
      "Inv #",
      "Client",
      "Package #",
      "Bottles",
      "Total",
      "Status",
      "Emailed"
    ]

    # Data rows
    @invoices.each do |invoice|
      issued_date = invoice.issued_at ? format_date(invoice.issued_at) : "—"
      client_name = invoice.client[:company_name] || "—"
      package_num = invoice.wine_package&.id || "—"
      bottle_count = invoice.billable_bottle_count || 0
      total_amount = invoice.total || 0
      status = invoice.status.capitalize
      emailed = invoice.email_sent_at.present? ? "Yes" : "No"

      table_data << [
        issued_date,
        invoice.invoice_number,
        client_name,
        package_num,
        bottle_count,
        number_to_currency(total_amount),
        status,
        emailed
      ]
    end

    pdf.table(table_data, header: true, cell_style: { size: 8 }, column_widths: column_widths) do
      row(0).font_style = :bold
      cells.borders = [:bottom]
    end
  end

  def draw_totals_row(pdf)
    return if @invoices.empty?

    pdf.move_down 5
    pdf.fill_color "27615e"
    pdf.fill_rect [40, pdf.bounds.top], pdf.bounds.width - 80, 20
    pdf.fill_color "4a1020"

    total_count = @invoices.size
    total_sum = @invoices.sum(&:total) || 0

    pdf.draw_text "Total: #{total_count} invoices — #{number_to_currency(total_sum)}", size: 10, at: [40, pdf.bounds.top - 15]
    pdf.fill_color "4a1020"
  end

  def draw_footer(pdf)
    pdf.move_down 30
    pdf.fill_color "766963"
    pdf.draw_text "Generated at #{Time.current.strftime('%Y-%m-%d %H:%M')}", size: 8, at: [40, 30]
    pdf.draw_text "Wine Words - Invoice Report", size: 8, at: [400, 30]
    pdf.fill_color "4a1020"
  end

  def filter_status_description
    return unless @filters[:status].present? && @filters[:status] != "all"

    case @filters[:status]
    when "sent" then "Status: Sent"
    when "paid" then "Status: Paid"
    when "cancelled" then "Status: Cancelled"
    end
  end

  def filter_email_description
    return unless @filters[:email_sent].present? && @filters[:email_sent] != "all"

    case @filters[:email_sent]
    when "sent" then "Emailed: Yes"
    when "not_sent" then "Emailed: No"
    end
  end

  def filter_payment_source_description
    return unless @filters[:payment_source].present? && @filters[:payment_source] != "all"

    case @filters[:payment_source]
    when "manual" then "Payment Source: Manual"
    when "stripe" then "Payment Source: Stripe"
    end
  end

  def filter_overdue_description
    return unless @filters[:overdue].present?

    "Overdue Only: #{@filters[:overdue] ? "Yes" : "No"}"
  end

  def format_date(date)
    return "—" unless date
    date.strftime("%b %d, %Y")
  end

  def number_to_currency(number)
    return "—" unless number
    # Simple number formatting - in production would use number_to_currency helper
    format("%.2f", number)
  end
end