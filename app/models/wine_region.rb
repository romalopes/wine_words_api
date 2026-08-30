class WineRegion < ApplicationRecord
  self.table_name = "wine_regions"

  belongs_to :wine
  belongs_to :region

  validates :wine_id, uniqueness: { scope: :region_id }
end