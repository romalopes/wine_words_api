class WineSerializer
  def initialize(wine, base_url = nil)
    @wine = wine
    @base_url = base_url
  end

  def as_json
    {
      id: @wine.id,
      slug: @wine.slug,
      name: @wine.name,
      color: @wine.color,
      sparkling: @wine.sparkling,
      closure: @wine.closure,
      alcohol_percentage: @wine.alcohol_percentage&.to_f,
            volume_ml: @wine.volume_ml,
             volume_label: @wine.volume_label,
      prompt: @wine.prompt,
            images: image_urls(@wine),
      image_ids: image_ids(@wine),
      producer: producer,
      category: @wine.category&.name,
      category_id: @wine.category_id,
      grapes: grapes,
      regions: regions,
      parameters: parameters,
      vintages: @wine.vintages.order(year: :desc).map do |v|
        {
          id: v.id,
          year: v.year,
          prompt: v.prompt,
          price: v.price&.to_f,
          no_vintage: v.no_vintage
        }
      end
    }
  end

  private

  def image_urls(record)
    return [] unless record.images.attached?

    record.images.map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(image, host: @base_url || "localhost:3000")
    end
  end

  def image_ids(record)
    return [] unless record.images.attached?

    record.images.map(&:id)
  end

  def producer
    return nil unless @wine.producer

    {
      id: @wine.producer.id,
      slug: @wine.producer.slug,
      name: @wine.producer.name,
      address: @wine.producer.address,
      email: @wine.producer.email
    }
  end

  def parameters
    # @wine.wine_taste_parameters.to_h do |wtp|
    #   [wtp.taste_parameter.slug, wtp.score]
    # end
    @wine.wine_taste_parameters.map do |wtp|
    {
      id: wtp.id,
      taste_parameter_id: wtp.taste_parameter_id,
      taste_parameter_slug: wtp.taste_parameter.slug,
      score: wtp.score
    }
end
  end

    def grapes
    @wine.grapes.map do |grape|
      {
        id: grape.id,
        name: grape.name,
        color: grape.color
      }
    end
  end

  def regions
    @wine.regions.includes(:country).map do |region|
      {
        id: region.id,
        name: region.name,
        country: {
          id: region.country.id,
          name: region.country.name,
          code: region.country.code,
          flag_emoji: region.country.flag_emoji
        },
        is_state: region.is_state,
        is_appellation: region.is_appellation
      }
    end
  end
end