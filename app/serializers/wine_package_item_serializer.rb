# One line of a WinePackage: the wine (catalogue vintage or producer proposal),
# whether a review was requested, and how that review is progressing.
#
# Issue #199 additions: a producer request may name wines that are not in the
# catalogue yet (`proposed_wine_name` / `proposed_vintage_year`); the wine
# fields fall back to the proposal so the producer always sees what they asked
# for. "Reviewed" is derived from the linked review's status — there is no
# stored flag — so unpublishing a review is immediately reflected here.
class WinePackageItemSerializer
  def initialize(item, base_url = nil)
    @item = item
    @base_url = base_url
  end

  def as_json
    wine = @item.vintage&.wine || @item.catalogue_wine
    producer = wine&.producer
    {
      id: @item.id,
      wine_package_id: @item.wine_package_id,
      vintage_id: @item.vintage_id,
      wine_id: @item.vintage&.wine_id,
      wine_name: wine&.name || @item.proposed_wine_name,
      wine_slug: wine&.slug,
      vintage_year: @item.vintage&.year,
      vintage_no_vintage: @item.vintage&.no_vintage,
      # Catalogue wine producer (for multi-producer display).
      producer_id: producer&.id,
      producer_name: producer&.name,
      producer_slug: producer&.slug,
      # Producer proposal (when the wine is not in the catalogue yet).
      proposed_wine_name: @item.proposed_wine_name,
      proposed_vintage_year: @item.proposed_vintage_year,
      label: @item.label,
      quantity: @item.quantity,
      review_requested: @item.review_requested,
      condition: @item.condition,
      notes: @item.notes,
      received_at: iso(@item.received_at),
      review_id: @item.review_id,
      review_status: @item.review&.status,
      review_slug: @item.review&.slug,
      reviewed: @item.reviewed?,
      reviewable: @item.reviewable?,
      pending_review: @item.pending_review?,
      # Resolution status derived from catalogue associations.
      resolution_status: @item.resolution_status,
      unmatched: @item.unmatched?,
      created_at: iso(@item.created_at),
      updated_at: iso(@item.updated_at)
    }
  end

  private

  def iso(time)
    time&.iso8601
  end
end
