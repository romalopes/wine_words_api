class NormalizeWineClosures < ActiveRecord::Migration[8.1]
  # Canonical values (see Wine::CLOSURES). Maps legacy/free-text spellings.
  CANONICAL = {
    "cork" => "Cork",
    "synthetic cork" => "Synthetic",
    "synthetic" => "Synthetic",
    "glass stopper" => "Glass Stopper",
    "glass" => "Glass Stopper",
    "screwcap" => "Screw cap",
    "screw cap" => "Screw cap"
  }.freeze

  def up
    Wine.where.not(closure: nil).find_each do |wine|
      value = wine.closure
      next if Wine::CLOSURES.include?(value)

      canonical = CANONICAL[value.to_s.downcase.strip] ||
                  Wine::CLOSURES.find { |c| c.downcase == value.to_s.downcase.strip }
      wine.update_column(:closure, canonical) if canonical
    end
  end

  def down
    # No-op: legacy free-text values cannot be restored.
  end
end