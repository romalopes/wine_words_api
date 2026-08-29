class WineGrape < ApplicationRecord
  belongs_to :wine
  belongs_to :grape

  validates :grape_id, uniqueness: { scope: :wine_id }
end