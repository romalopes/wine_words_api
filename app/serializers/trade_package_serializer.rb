# Trade-package view (IDENTITY_206): one serializer, three viewer scopes.
#
#   viewer: :submitter  — the claiming owner: contact snapshot, timeline
#                         (shared events only), items, commercial summary
#   viewer: :guest      — guest-token holder: read-only subset, NO contact
#                         snapshot email beyond what they submitted
#   viewer: :staff      — Editor/Admin: adds internal events/notes, shipping
#                         override audit, contact snapshot in full
#
# The confidentiality boundary is enforced here and in the queries feeding it:
# internal WinePackageEvents are only ever serialised for staff.
class TradePackageSerializer
  def initialize(wine_package, base_url = nil, viewer: :submitter, current_user_id: nil)
    @package = wine_package
    @base_url = base_url
    @viewer = viewer.to_s
    @current_user_id = current_user_id
  end

  def as_json(*)
    {
      id: @package.id,
      status: @package.status,
      source: @package.source,
      claimed: @package.claimed?,
      created_at: iso(@package.created_at),
      submitted_at: iso(@package.submitted_at),
      items: items_json,
      events: events_json,
      quotes: quotes_json,
      invoices: invoices_json,
      shipping: shipping_json
    }.merge(contact_json).merge(guest_only_extras)
  end

  private

  def items_json
    @package.wine_package_items
            .includes(vintage: { wine: :producer }, catalogue_wine: :producer)
            .order(:id)
            .map do |item|
      # The submitted snapshot is NEVER overwritten; once the Wine Words team
      # resolves the line we expose the linked catalogue wine/vintage alongside
      # it so submitters and staff see which wine is actually being reviewed.
      resolved_wine = item.vintage&.wine || item.catalogue_wine
      resolved_vintage = item.vintage
      {
        id: item.id,
        # Submitted snapshot (source information from the submitter). Lines the
        # Wine Words team added from the catalogue have no snapshot, so fall
        # back to the resolved catalogue identity for display.
        wine_name: item.snapshot_wine_name.presence || resolved_wine&.name,
        quantity: item.quantity,
        vintage: item.snapshot_vintage_display.presence || vintage_label_for(resolved_vintage),
        region: item.snapshot_region,
        appellation: item.snapshot_appellation,
        grape_varieties: item.snapshot_grape_varieties,
        abv: item.snapshot_abv,
        volume_ml: item.snapshot_volume_ml,
        closure_type: item.snapshot_closure_type,
        tasting_notes: item.snapshot_tasting_notes,
        technical_sheet_url: item.snapshot_technical_sheet_url,
        trade_price: item.snapshot_trade_price,
        retail_price: item.snapshot_retail_price,
        sample_available: item.snapshot_sample_available,
        sample_quantity: item.snapshot_sample_quantity,
        # Resolved catalogue match (nil until the team links a wine/vintage).
        # `submitted` tells the UI whether there was an original snapshot name
        # to reconcile (false for lines the team added from the catalogue).
        submitted: item.snapshot_wine_name.present?,
        resolved: resolved_wine.present? && resolved_vintage.present?,
        catalogue_wine_id: resolved_wine&.id,
        catalogue_wine_name: resolved_wine&.name,
        catalogue_wine_slug: resolved_wine&.slug,
        catalogue_producer_id: resolved_wine&.producer_id,
        catalogue_producer_name: resolved_wine&.producer&.name,
        catalogue_producer_slug: resolved_wine&.producer&.slug,
        vintage_id: resolved_vintage&.id,
        vintage_year: resolved_vintage&.year,
        vintage_no_vintage: resolved_vintage&.no_vintage,
        vintage_label: vintage_label_for(resolved_vintage),
        item_status: item.item_status,
        review_progress: review_progress_for(item),
        received: item.receipt_recorded?,
        condition: item.condition
      }
    end
  end

  def vintage_label_for(vintage)
    return nil if vintage.nil?

    vintage.no_vintage ? "NV" : vintage.year&.to_s
  end

  def review_progress_for(item)
    return "not_eligible" unless item.review_requested || item.review

    if item.reviewed?
      "published"
    elsif item.review
      "in_progress"
    else
      "assigned"
    end
  end

  def events_json
    visible = staff? ? @package.wine_package_events : @package.wine_package_events.shared
    visible.chronological.map do |event|
      {
        id: event.id,
        event_type: event.event_type,
        occurred_at: iso(event.occurred_at),
        description: event.description,
        internal: event.internal?
      }
    end
  end

  def quotes_json
    return [] unless staff? || @viewer == "submitter"

    @package.wine_package_quotes.order(:created_at).map do |quote|
      {
        id: quote.id, service_type: quote.service_type, status: quote.status,
        subtotal: quote.subtotal, tax: quote.tax, total: quote.total,
        currency: quote.currency, valid_until: quote.valid_until
      }
    end
  end

  def invoices_json
    return [] unless staff? || @viewer == "submitter"

    @package.wine_package_invoices.order(:created_at).map do |invoice|
      {
        id: invoice.id, invoice_number: invoice.invoice_number, status: invoice.status,
        subtotal: invoice.subtotal, tax: invoice.tax, total: invoice.total,
        currency: invoice.currency, issued_at: iso(invoice.issued_at), due_at: iso(invoice.due_at),
        paid_at: iso(invoice.paid_at)
      }
    end
  end

  def shipping_json
    base = {
      address: staff? || @viewer == "submitter" ? @package.shipping_address : nil,
      tracking: tracking_json,
      override: staff? ? override_json : nil
    }
    base
  end

  def tracking_json
    {
      carrier: @package.tracking_carrier,
      number: @package.tracking_number,
      url: @package.tracking_url,
      status: @package.tracking_status,
      updated_at: iso(@package.tracking_status_updated_at)
    }
  end

  def override_json
    {
      overridden: @package.shipping_override_at.present?,
      reason: @package.shipping_override_reason,
      at: iso(@package.shipping_override_at)
    }
  end

  def contact_json
    return {} unless staff? || @viewer == "submitter"

    { contact_snapshot: @package.contact_snapshot }
  end

  # A guest additionally learns whether/how they can claim the package.
  def guest_only_extras
    return {} unless @viewer == "guest"

    { # claimable is true if the package can be claimed by the current viewer.
    # For authenticated users, it's claimable if not already claimed by them.
    # For guests, it's claimable if not claimed at all.
    claimable: if @viewer != "guest" && @current_user_id
                 !@package.claimed? || @package.submitter_id != @current_user_id
               else
                 !@package.claimed?
               end }
  end

  def staff? = @viewer == "staff"

  def iso(value) = value&.iso8601
end