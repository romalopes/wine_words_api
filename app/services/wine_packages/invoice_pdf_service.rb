# Explicit requires: this service is lazy-loaded by Zeitwerk when the invoice
# mailer job first runs. Bundler.require normally loads Prawn at boot, but an
# explicit require makes the class self-sufficient in any deployment where the
# bundle was updated without a process restart (and keeps the dependency
# obvious to readers). Prawn itself requires `matrix` (a bundled gem on Ruby
# >= 3.1, present in the Gemfile), so requiring prawn first also surfaces a
# missing bundle as a clear "prawn" LoadError rather than a confusing one.
require "prawn"

module WinePackages
  # Generates a professional PDF invoice using Prawn (pure Ruby).
  #
  # Usage:
  #   pdf = InvoicePdfService.call(invoice)
  #   pdf.render  # returns binary PDF string
  #   pdf.render_file("path.pdf")
  class InvoicePdfService
    include Prawn::View

    # Page layout constants
    MARGIN = 40
    LOGO_HEIGHT = 60
    TABLE_HEADER_HEIGHT = 30
    ROW_HEIGHT = 25

    def self.call(invoice)
      new(invoice).generate
    end

    def initialize(invoice)
      @invoice = invoice
      @package = invoice.wine_package
      @owner = resolve_owner
      @document = Prawn::Document.new(page_size: "A4", margin: MARGIN)
    end

    def generate
      draw_header
      draw_bill_to
      draw_line_items
      draw_totals
      draw_payment_instructions
      draw_footer
      self
    end

    private

    attr_reader :invoice, :package, :owner

    def draw_header
      logo_top = bounds.top

      if logo_file_present?
        # "wine words" wordmark (3:1 banner). Drawn large as the primary
        # branding element; the separate text wordmark is dropped since the
        # logo already contains the name.
        image logo_path.to_s, width: 150, at: [bounds.left, logo_top]

        # Tagline under the logo
        bounding_box([bounds.left, logo_top - 58], width: 280, height: 20) do
          font_size 10
          font "Helvetica", style: :normal
          fill_color "766963"
          text "Premium Wine Review & Publication", align: :left
        end
      else
        # Text-only fallback when the logo asset is missing so PDF generation
        # never fails on packaging.
        bounding_box([bounds.left, logo_top - 10], width: 280, height: 84) do
          font_size 24
          font "Helvetica", style: :bold
          fill_color "4A1020"
          text "WINE WORDS", align: :left

          font_size 10
          font "Helvetica", style: :normal
          fill_color "766963"
          text "Premium Wine Review & Publication", align: :left
        end
      end

      # Invoice meta (right-aligned, top of the page) — auto-height box so the
      # label/value pairs can never be clipped.
      bounding_box([bounds.right - 220, logo_top - 10], width: 220) do
        font_size 14
        font "Helvetica", style: :bold
        fill_color "4A1020"
        text "INVOICE", align: :right

        move_down 8
        font_size 10
        font "Helvetica", style: :normal
        fill_color "241B19"
        meta_items = [
          ["Invoice #", invoice.invoice_number],
          ["Date", invoice.issued_at&.strftime("%d %b %Y") || "—"],
          ["Due Date", invoice.due_at&.strftime("%d %b %Y") || "—"],
          ["Status", invoice.status.to_s.upcase]
        ]
        meta_items.each do |label, value|
          font "Helvetica", style: :bold
          text "#{label}:", align: :right
          font "Helvetica", style: :normal
          text value.to_s, align: :right
          move_down 4
        end
      end

      # Clear the header block before the divider
      move_down 4
      stroke_color "E4D9CD"
      stroke_horizontal_rule
      move_down 20
    end

    def draw_bill_to
      font_size 12
      font "Helvetica", style: :bold
      fill_color "4A1020"
      text "BILL TO", align: :left

      move_down 8
      font_size 10
      font "Helvetica", style: :normal
      fill_color "241B19"

      bill_to_lines = []
      bill_to_lines << owner[:company_name] if owner[:company_name].present?
      bill_to_lines << owner[:contact_name] if owner[:contact_name].present?
      bill_to_lines << owner[:email] if owner[:email].present?
      bill_to_lines << owner[:address] if owner[:address].present?
      bill_to_lines << "#{owner[:country]}" if owner[:country].present?

      bill_to_lines.each { |line| text line }

      move_down 20
      stroke_color "E4D9CD"
      stroke_horizontal_rule
      move_down 20
    end

    def draw_line_items
      # Table header
      font_size 10
      font "Helvetica", style: :bold
      fill_color "FFFFFF"
      fill_rectangle [bounds.left, cursor], bounds.width, TABLE_HEADER_HEIGHT
      fill_color "4A1020"

      col_widths = [280, 60, 100, 100]
      headers = ["DESCRIPTION", "QTY", "UNIT PRICE", "TOTAL"]
      x = bounds.left
      font "Helvetica", style: :bold
      headers.each_with_index do |header, i|
        draw_text header, at: [x + 5, cursor - 7], size: 10
        x += col_widths[i]
      end
      font "Helvetica"

      move_down TABLE_HEADER_HEIGHT

      # Line item (single row for review fee)
      font_size 10
      font "Helvetica", style: :normal
      fill_color "241B19"

      item_data = [
        "Wine Review Fee (per bottle)",
        invoice.billable_bottle_count.to_s,
        format_currency(invoice.unit_fee),
        format_currency(invoice.unit_fee * invoice.billable_bottle_count)
      ]

      x = bounds.left
      item_data.each_with_index do |val, i|
        draw_text val, at: [x + 5, cursor - 7], size: 10
        x += col_widths[i]
      end

      move_down ROW_HEIGHT
      stroke_color "E4D9CD"
      stroke_horizontal_rule
      move_down 10
    end

def draw_totals
      # Right-aligned totals box
      bounding_box([bounds.right - 220, cursor], width: 220) do
        font_size 10
        font "Helvetica", style: :normal
        fill_color "241B19"

        totals = [
          ["Subtotal", format_currency(invoice.subtotal)],
          ["GST (#{(AppSetting.invoice_gst_rate || 0.10) * 100}.0%)", format_currency(invoice.tax)],
        ]

        totals.each do |label, value|
          font "Helvetica", style: :normal
          text "#{label}:", align: :left
          font "Helvetica", style: :normal
          text value.to_s, align: :right
          move_down 6
        end

        move_down 4
        stroke_color "E4D9CD"
        stroke_horizontal_rule
        move_down 8

        font_size 12
        font "Helvetica", style: :bold
        fill_color "4A1020"
        font "Helvetica", style: :bold
        text "TOTAL:", align: :left
        font "Helvetica", style: :bold
        text format_currency(invoice.total), align: :right
      end

      move_down 30
    end

    def draw_payment_instructions
      font_size 12
      font "Helvetica", style: :bold
      fill_color "4A1020"
      text "PAYMENT INSTRUCTIONS", align: :left

      move_down 8
      font_size 10
      font "Helvetica", style: :normal
      fill_color "241B19"

      instructions = [
        "Please pay via bank transfer using the details below:",
        "",
        "Bank: Commonwealth Bank of Australia",
        "Account Name: Wine Words Pty Ltd",
        "BSB: 062-000",
        "Account: 1234 5678",
        "Reference: #{invoice.invoice_number} (required)",
        "",
        "Please include the invoice number as reference to ensure prompt processing."
      ]

      instructions.each { |line| text line }

      move_down 20
      stroke_color "E4D9CD"
      stroke_horizontal_rule
      move_down 15
    end

    def draw_footer
      font_size 9
      font "Helvetica", style: :normal
      fill_color "766963"

      footer_text = [
        "This invoice covers the review of #{invoice.billable_bottle_count} bottle(s) submitted under package ##{package.id}.",
        "Payment due within 30 days of invoice date.",
        "",
        "Wine Words Pty Ltd  |  support@beachvolleyballhub.com  |  ABN: 12 345 678 901"
      ]

      footer_text.each { |line| text line, align: :center }
    end

    def resolve_owner
      # Priority: contact_snapshot (trade submissions) > linked user > producer
      if package.contact_snapshot.present?
        snap = package.contact_snapshot
        {
          company_name: snap["company_name"],
          contact_name: snap["contact_name"] || snap["company_name"],
          email: snap["email"],
          address: snap["address"],
          country: snap["country"]
        }
      elsif package.producer.present?
        {
          company_name: package.producer.name,
          contact_name: package.producer.name,
          email: package.producer.users&.first&.email,
          address: nil,
          country: "Australia"
        }
      elsif package.requested_by.present?
        {
          company_name: nil,
          contact_name: package.requested_by.display_name,
          email: package.requested_by.email,
          address: nil,
          country: "Australia"
        }
      else
        {
          company_name: "Valued Client",
          contact_name: "Client",
          email: "client@example.com",
          address: nil,
          country: "Australia"
        }
      end
    end

    def format_currency(amount)
      return "—" if amount.nil?
      currency = invoice.currency || "AUD"
      "#{'%0.2f' % amount} #{currency}"
    end

    # Branding asset shipped with the API: the "wine words" wordmark copied
    # from the frontend and converted to JPEG (the frontend source file is a
    # WebP with a .jpg extension, which Prawn cannot embed).
    def logo_path
      Rails.root.join("app/assets/images/wine_words_logo.jpg")
    end

    def logo_file_present?
      File.exist?(logo_path)
    end
  end
end