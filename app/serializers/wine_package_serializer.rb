# Full-detail serializer for Api::V1::WinePackagesController#show / #create /
# #update and every workflow action. Ships the lifecycle dates, the tracking
# snapshot, the items, review progress and the workflow capabilities the React
# detail page uses to decide which action buttons to render.
#
# Issue #199 additions:
#   * producer-owned metadata (producer_reference/producer_notes/shipping_notes,
#     requested_by_id, submitted_at) — always shipped;
#   * `viewer:` scopes the editorial fields: an editorial viewer (admin/editor/
#     the assigned reviewer) sees `notes` and `internal_notes`, a producer
#     viewer never does, and the assigned reviewer's identity stays hidden from
#     the producer side until the product decides otherwise (§9);
#   * `submit` / `withdraw` capabilities for the producer request wizard.
class WinePackageSerializer
  def initialize(wine_package, base_url = nil, viewer: nil)
    @package = wine_package
    @base_url = base_url
    @viewer = viewer
  end

  def as_json
    {
      id: @package.id,
      producer_id: @package.producer_id,
      producer_name: @package.producer&.name,
      producer_slug: @package.producer&.slug,
      reviewer_id: @package.reviewer_id,
      reviewer_name: reviewer_name,
      created_by_id: @package.created_by_id,
      requested_by_id: @package.requested_by_id,
      status: @package.status,
      source: @package.source,
      announced_at: iso(@package.announced_at),
      expected_at: date(@package.expected_at),
      arrived_at: iso(@package.arrived_at),
      review_deadline: date(@package.review_deadline),
      reviewed_at: iso(@package.reviewed_at),
      auto_completed: @package.auto_completed,
      tracking: tracking_json,
      requested_at: iso(@package.requested_at),
      submitted_at: iso(@package.submitted_at),
      accepted_at: iso(@package.accepted_at),
      accepted_by_id: @package.accepted_by_id,
      rejected_at: iso(@package.rejected_at),
      rejected_by_id: @package.rejected_by_id,
      rejection_reason: @package.rejection_reason,
      producer_reference: @package.producer_reference,
      producer_notes: @package.producer_notes,
      shipping_notes: @package.shipping_notes,
      # Editorial-only notes — never shipped to a producer viewer (§8).
      notes: editorial_viewer? ? @package.notes : nil,
      internal_notes: editorial_viewer? ? @package.internal_notes : nil,
      items: items,
      review_progress: @package.review_progress,
      pending_review_count: @package.pending_review_count,
      reviews_complete: @package.reviews_complete?,
      overdue: @package.overdue?,
      days_until_deadline: @package.days_until_deadline,
      can: capabilities,
      images: image_urls(@package),
      image_ids: image_ids(@package),
      image_details: image_details(@package),
      primary_image: primary_image(@package),
      created_at: iso(@package.created_at),
      updated_at: iso(@package.updated_at)
    }
  end

  private

  include ImageAttributes

  def reviewer_name
    return nil unless editorial_viewer?

    @package.reviewer&.display_name || @package.reviewer&.email
  end

  # The denormalized snapshot kept on the package by ShipmentTracking.
  def tracking_json
    {
      carrier: @package.tracking_carrier,
      number: @package.tracking_number,
      url: @package.tracking_url,
      status: @package.tracking_status,
      status_updated_at: iso(@package.tracking_status_updated_at),
      estimated_delivery_at: iso(@package.estimated_delivery_at),
      delivered_at: iso(@package.delivered_at)
    }
  end

  def items
    @package.wine_package_items.map do |item|
      WinePackageItemSerializer.new(item, @base_url).as_json
    end
  end

  # Which workflow actions the package currently allows, so the UI never offers
  # a button the transition guard would reject. Producer-facing actions
  # (submit/withdraw) are included for the producer request wizard; the
  # controller still enforces who may actually perform them.
  def capabilities
    {
      mark_in_transit: @package.can_transition_to?("in_transit"),
      mark_arrived: @package.can_transition_to?("arrived"),
      start_reviewing: @package.can_transition_to?("reviewing"),
      mark_completed: @package.can_transition_to?("completed"),
      reopen: @package.can_transition_to?("reviewing") && @package.completed?,
      cancel: @package.can_transition_to?("cancelled"),
      accept: @package.can_transition_to?("accepted"),
      reject: @package.can_transition_to?("rejected"),
      submit: @package.draft? && @package.can_transition_to?("requested"),
      withdraw: @package.requested? && @package.can_transition_to?("cancelled")
    }
  end

  # Admins, editors and the assigned reviewer see the editorial fields. With no
  # viewer supplied (console/legacy calls) the editorial view is assumed.
  def editorial_viewer?
    return true if @viewer.nil?

    @viewer.catalogue_manager? || @viewer.id == @package.reviewer_id
  end

  def iso(time)
    time&.iso8601
  end

  def date(value)
    value&.iso8601
  end
end
