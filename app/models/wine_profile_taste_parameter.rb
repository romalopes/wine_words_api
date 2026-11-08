class WineProfileTasteParameter < ApplicationRecord
   belongs_to :wine_profile
  belongs_to :taste_parameter

  validates :wine_profile_id, presence: true
  validates :taste_parameter_id, presence: true
  validates :score, presence: true
end
