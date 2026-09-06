class Address < ApplicationRecord
  DEFAULT_COUNTRY_CODE = Producer::DEFAULT_COUNTRY_CODE

  belongs_to :producer
  belongs_to :country

  validates :producer_id, uniqueness: true

  # Addresses always belong to a country; new/legacy rows default to Australia,
  # mirroring Producer#set_default_country.
  before_validation :set_default_country

  # Convenience for consumers that previously read producer.address (a plain
  # string) — e.g. producers_helper and the search pickers.
  def street_or_blank
    street_address.to_s
  end

  private

  def set_default_country
    return if country_id.present?

    self.country = Country.find_or_create_by!(code: DEFAULT_COUNTRY_CODE) do |c|
      c.name = "Australia"
      c.continent = "Oceania"
    end
  end
end