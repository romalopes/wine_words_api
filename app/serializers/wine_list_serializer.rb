# Lean serializer used by Api::V1::WinesController#index (list views) only.
# It ships only the fields the list/card/table UIs render, plus a single
# pre-computed vintage count, avoiding the full detail payload (vintages,
# taste parameters, region countries, image blobs) that dominates response
# size and slows the "All Wines" page as the wine library grows.
class WineListSerializer
  def initialize(wine, base_url = nil, vintage_counts = {})
    @wine = wine
    @base_url = base_url
    @vintage_counts = vintage_counts
  end

  def as_json
    {
      id: @wine.id,
      slug: @wine.slug,
      name: @wine.name,
      color: @wine.color,
      sparkling: @wine.sparkling,
      category: @wine.categories.map(&:name).join(", ").presence,
      producer: producer,
      grapes: grapes,
      regions: regions,
      vintages_count: @vintage_counts[@wine.id] || 0,
      images: image_urls(@wine)
    }
  end

  private

  def image_urls(record)
    return [] unless record.images.attached?

    record.images.map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(image, host: @base_url || "localhost:3000")
    end
  end

  def producer
    return nil unless @wine.producer

    {
      id: @wine.producer.id,
      slug: @wine.producer.slug,
      name: @wine.producer.name
    }
  end

  def grapes
    @wine.grapes.map { |grape| { id: grape.id, slug: grape.slug, name: grape.name } }
  end

  def regions
    @wine.regions.map { |region| { id: region.id, slug: region.slug, name: region.name } }
  end
end