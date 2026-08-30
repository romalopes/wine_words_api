class Region < ApplicationRecord
  belongs_to :country
  belongs_to :parent, class_name: "Region", optional: true
  has_many :sub_regions, class_name: "Region", foreign_key: "parent_id", dependent: :destroy

  has_many :wine_regions, dependent: :destroy
  has_many :wines, through: :wine_regions

  validates :name, presence: true
  validates :name, uniqueness: { scope: :parent_id }
  validates :country, presence: true
  validate :parent_must_be_in_same_country

  # Class method to build a tree of regions grouped by country
  def self.build_tree
    # Get all regions with their countries
    all_regions = includes(:country).order(:name)
    
    # Get wine counts per region (region_id => count) in a single query
    wine_counts = WineRegion.group(:region_id).count
    
    # Group by country and build tree structure
    countries = Country.includes(:regions).order(:name)

    countries.map do |country|
      tree = build_region_tree(all_regions, country.id, wine_counts)
      {
        id: country.id,
        name: country.name,
        code: country.code,
        flag_emoji: country.flag_emoji,
        continent: country.continent,
        wine_count: tree.sum { |r| r[:wine_count] },
        regions: tree
      }
    end
  end

  # Recursively build region tree for a country
  def self.build_region_tree(all_regions, country_id, wine_counts)
    # Get top-level regions for this country
    country_regions = all_regions.select { |r| r.country_id == country_id }
    build_tree_nodes(country_regions, nil, wine_counts)
  end

  # Build tree nodes recursively, computing wine counts bottom-up
  def self.build_tree_nodes(regions, parent_id, wine_counts)
    nodes = regions.select { |r| r.parent_id == parent_id }.map do |region|
      children = build_tree_nodes(regions, region.id, wine_counts)
      direct_wines = wine_counts[region.id] || 0
      child_wines = children.sum { |c| c[:wine_count] }
      {
        id: region.id,
        name: region.name,
        is_state: region.is_state,
        is_appellation: region.is_appellation,
        parent_id: region.parent_id,
        wine_count: direct_wines + child_wines,
        children: children
      }
    end

    # Sort children by name
    nodes.sort_by { |n| n[:name] }
  end

  # Get the full path from country to this region
  def full_path
    path = []
    current = self
    country = current.country

    path << {
      type: 'country',
      id: country.id,
      name: country.name,
      flag_emoji: country.flag_emoji,
      code: country.code
    }

    # Walk up the hierarchy
    ancestors = []
    while current.parent
      ancestors << {
        type: 'region',
        id: current.parent.id,
        name: current.parent.name,
        is_state: current.parent.is_state,
        is_appellation: current.parent.is_appellation,
        parent_id: current.parent.parent_id
      }
      current = current.parent
    end

    # Reverse to get correct order (country -> ... -> current region)
    path + ancestors.reverse + [{
      type: 'region',
      id: self.id,
      name: self.name,
      is_state: self.is_state,
      is_appellation: self.is_appellation,
      parent_id: self.parent_id
    }]
  end

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