class WineProfileRegion < ApplicationRecord
  belongs_to :wine_profile
  belongs_to :region
end