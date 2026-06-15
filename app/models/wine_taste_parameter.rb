class WineTasteParameter < ApplicationRecord
  belongs_to :wine
  belongs_to :taste_parameter

  # validates :wine_id, presence: true
  validates :taste_parameter_id, presence: true
  validates :score, presence: true
end