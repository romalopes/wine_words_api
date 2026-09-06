module ProducersHelper
  def producer_color_class(producer)
    "producer-card--#{producer.name.to_s.parameterize.presence || 'unknown'}"
  end

  def producer_details(producer)
    [
      producer.address&.street_address.presence,
      producer.email.presence
    ].compact.join(" · ")
  end
end