# Lean serializer used by Api::V1::WinesController#index (list views) only.
# It ships only the fields the list/card/table UIs render, plus a single
# pre-computed vintage count, avoiding the full detail payload (vintages,
# taste parameters, region countries, image blobs) that dominates response
# size and slows the "All Wines" page as the wine library grows.
class WineListSerializer
  include ImageAttributes
  include LikeAttributes

  def initialize(wine, base_url = nil, vintage_counts = {}, liked_ids: nil, user: nil)
    @wine = wine
    @base_url = base_url
    @vintage_counts = vintage_counts
    @liked_ids = liked_ids
    @user = user
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
      parameters: parameters,
      vintages_count: @vintage_counts[@wine.id] || 0,
      **like_fields(@wine, @liked_ids),
      images: image_urls(@wine)
    }
  end

  private

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

  def parameters
    @wine.wine_taste_parameters.map do |wtp|
      param = {
        id: wtp.id,
        taste_parameter_id: wtp.taste_parameter_id,
        taste_parameter_slug: wtp.taste_parameter.slug
      }
      # Only include score if user is linked to the wine (admin/editor/reviewer, reviewer, producer member)
      param[:score] = @wine.user_linked?(@user) ? wtp.score : nil
      param
    end
  end
end
