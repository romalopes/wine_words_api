class WineProfileGrape < ApplicationRecord
  belongs_to :wine_profile
  belongs_to :grape
end