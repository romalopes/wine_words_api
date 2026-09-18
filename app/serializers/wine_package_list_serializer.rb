# Lean serializer used by Api::V1::WinePackagesController#index only. Ships the
# fields the packages list renders (and filters on) without the item detail.
class WinePackageListSerializer
  def initialize(wine_package, base_url = nil)
    @package = wine_package
    @base_url = base_url
  end

  def as_json
    progress = @package.review_progress

    {
      id: @package.id,
      producer_id: @package.producer_id,
      producer_name: @package.producer&.name,
      producer_slug: @package.producer&.slug,
      reviewer_id: @package.reviewer_id,
      reviewer_name: @package.reviewer&.user_name || @package.reviewer&.email,
      status: @package.status,
      source: @package.source,
      expected_at: date(@package.expected_at),
      arrived_at: iso(@package.arrived_at),
      review_deadline: date(@package.review_deadline),
      reviewed_at: iso(@package.reviewed_at),
      items_count: @package.wine_package_items.size,
      pending_review_count: progress[:pending],
      review_progress: progress,
      auto_completed: @package.auto_completed,
      tracking_status: @package.tracking_status,
      overdue: @package.overdue?,
      days_until_deadline: @package.days_until_deadline,
      created_at: iso(@package.created_at),
      updated_at: iso(@package.updated_at)
    }
  end

  private

  def iso(time)
    time&.iso8601
  end

  def date(value)
    value&.iso8601
  end
end
