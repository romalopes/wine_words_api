class Region < ApplicationRecord
  belongs_to :country
  belongs_to :parent, class_name: "Region", optional: true
  has_many :sub_regions, class_name: "Region", foreign_key: "parent_id", dependent: :destroy

    has_many :wine_regions, dependent: :destroy
  has_many :wines, through: :wine_regions

  validates :name, presence: true
  validates :name, uniqueness: { scope: :country_id }
  validates :country, presence: true
  validate :parent_must_be_in_same_country

  def display_name
    # Shows parent → name hierarchy when present (e.g. "Burgundy → Côte de Beaune")
    parent.present? ? "#{parent.display_name} → #{name}" : name
  end

  def region_type_label
    if is_state? && is_appellation?
      "State / Appellation"
    elsif is_state?
      "State"
    elsif is_appellation?
      "Appellation"
    else
      parent ? "Sub-region" : "Region"
    end
  end

  private

  def parent_must_be_in_same_country
    if parent.present? && parent.country_id != country_id
      errors.add(:parent, "must belong to the same country")
    end
  end
end