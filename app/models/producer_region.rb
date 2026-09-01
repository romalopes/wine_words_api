class ProducerRegion < ApplicationRecord
  belongs_to :producer
  belongs_to :region

  validates :producer_id, uniqueness: { scope: :region_id }
  validate :region_belongs_to_producer_country

  private

  def region_belongs_to_producer_country
    return if producer.blank? || region.blank?
    return if region.country_id == producer.country_id

    errors.add(:region, "must belong to the producer's country")
  end
end
