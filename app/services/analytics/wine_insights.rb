# Phase 10: Wine insights aggregation service.
#
# Aggregates Wine views through verified producer, region and grape associations.
# - Deduplicates duplicate association rows (many-to-many) so a single Wine event
#   is counted once per group, not multiplied by the number of associations.
# - Calculates group-level distinct identities correctly (across all wines in group).
# - Labels multi-grape/multi-region categories as overlapping and non-additive.
# - Returns period metadata and scope label.
#
# Does NOT present this as a conversion funnel -- only observed direct transitions
# Wine->Review are tracked via the `source` field on events.
module Analytics
  class WineInsights
    GROUPINGS = %w[producer region grape].freeze

    def self.call(scope, period, params)
      new(scope, period, params).call
    end

    def initialize(scope, period, params)
      @scope = scope
      @period = period
      @params = params
    end

    def call
      return empty_result if @period.empty?

      grouping = GROUPINGS.include?(@params[:grouping].to_s) ? @params[:grouping].to_s : "producer"
      sort = %w[views unique_viewers name].include?(@params[:sort].to_s) ? @params[:sort].to_s : "views"
      direction = %w[asc desc].include?(@params[:direction].to_s) ? @params[:direction].to_s : "desc"

      wine_ids = @scope.wines.pluck(:id)
      return empty_result if wine_ids.empty?

      events = Analytics::Event.accepted
        .where(viewable_type: "Wine", viewable_id: wine_ids)
        .in_window(@period.start_at, @period.end_at)

      case grouping
      when "producer"
        groups = build_producer_groups(wine_ids, events, sort, direction)
      when "region"
        groups = build_region_groups(wine_ids, events, sort, direction)
      when "grape"
        groups = build_grape_groups(wine_ids, events, sort, direction)
      end

      {
        grouping: grouping,
        groups: groups,
        period: @period.metadata.merge(scope: @scope.scope_label),
        overlapping_notice: overlapping_notice(grouping),
      }
    end
private

  def empty_result
    {
      grouping: @params[:grouping] || "producer",
      groups: [],
      period: @period.metadata.merge(scope: @scope.scope_label),
      overlapping_notice: nil,
    }
  end

  def overlapping_notice(grouping)
    case grouping
    when "grape"
      "A wine with multiple grapes is counted in each applicable grape group. Group totals are not additive -- the sum of grape views exceeds total wine views."
    when "region"
      "A wine with multiple regions is counted in each applicable region group. Group totals are not additive -- the sum of region views exceeds total wine views."
    else
      nil
    end
  end

  def build_producer_groups(wine_ids, events, sort, direction)
    wine_producers = Wine.where(id: wine_ids).pluck(:id, :producer_id).to_h
    producer_ids = wine_producers.values.uniq

    producers = Producer.where(id: producer_ids).pluck(:id, :name, :slug).to_h

    producer_events = events.pluck(:viewable_id, :identity, :viewed_at).group_by do |wine_id, _identity, _viewed_at|
      wine_producers[wine_id]
    end

    groups = producer_ids.map do |producer_id|
      producer_events_for_group = producer_events[producer_id] || []
      producer_name = producers[producer_id]&.dig(1) || "Unknown Producer"
      producer_slug = producers[producer_id]&.dig(2)

      views = producer_events_for_group.size
      unique_viewers = producer_events_for_group.map { |_, identity, _| identity }.uniq.size

      {
        id: producer_id,
        slug: producer_slug,
        name: producer_name,
        views: views,
        unique_viewers: unique_viewers,
      }
    end

    sort_groups(groups, sort, direction)
  end

  def build_region_groups(wine_ids, events, sort, direction)
    wine_regions = WineRegion.where(wine_id: wine_ids).pluck(:wine_id, :region_id)
    region_to_wines = wine_regions.group_by(&:last).transform_values { |arr| arr.map(&:first) }
    region_ids = region_to_wines.keys

    regions = Region.where(id: region_ids).pluck(:id, :name, :slug).to_h

    groups = region_ids.map do |region_id|
      wine_ids_for_region = region_to_wines[region_id]
      region_events = events.where(viewable_id: wine_ids_for_region).pluck(:viewable_id, :identity, :viewed_at)
      
      region_name = regions[region_id]&.dig(1) || "Unknown Region"
      region_slug = regions[region_id]&.dig(2)

      views = region_events.size
      unique_viewers = region_events.map { |_, identity, _| identity }.uniq.size

      {
        id: region_id,
        slug: region_slug,
        name: region_name,
        views: views,
        unique_viewers: unique_viewers,
      }
    end

    sort_groups(groups, sort, direction)
  end

  def build_grape_groups(wine_ids, events, sort, direction)
    wine_grapes = WineGrape.where(wine_id: wine_ids).pluck(:wine_id, :grape_id)
    grape_to_wines = wine_grapes.group_by(&:last).transform_values { |arr| arr.map(&:first) }
    grape_ids = grape_to_wines.keys

    grapes = Grape.where(id: grape_ids).pluck(:id, :name, :slug, :color).to_h

    groups = grape_ids.map do |grape_id|
      wine_ids_for_grape = grape_to_wines[grape_id]
      grape_events = events.where(viewable_id: wine_ids_for_grape).pluck(:viewable_id, :identity, :viewed_at)
      
      grape_name = grapes[grape_id]&.dig(1) || "Unknown Grape"
      grape_slug = grapes[grape_id]&.dig(2)
      grape_color = grapes[grape_id]&.dig(3)

      views = grape_events.size
      unique_viewers = grape_events.map { |_, identity, _| identity }.uniq.size

      {
        id: grape_id,
        slug: grape_slug,
        name: grape_name,
        color: grape_color,
        views: views,
        unique_viewers: unique_viewers,
      }
    end

    sort_groups(groups, sort, direction)
  end

  def sort_groups(groups, sort, direction)
    groups.sort_by! do |g|
      case sort
      when "views"
        g[:views]
      when "unique_viewers"
        g[:unique_viewers]
      when "name"
        g[:name].to_s.downcase
      else
        g[:views]
      end
    end

    groups.reverse! if direction == "desc"
    groups
  end
end
end
