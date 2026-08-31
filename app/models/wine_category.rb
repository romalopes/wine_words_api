class WineCategory < ApplicationRecord
  belongs_to :wine
  belongs_to :category

  validates :wine_id, uniqueness: { scope: :category_id }
end
