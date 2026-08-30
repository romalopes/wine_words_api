# db/seeds/volume_ml.rb
#
# Seeds canonical bottle volume records based on frontend/JS specifications.
# Usage: rails runner db/seeds/volume_ml.rb

VOLUMES = [
  { value: 187, label: "187.5 ml" },
  { value: 250, label: "250 ml" },
  { value: 375, label: "375 ml" },
  { value: 500, label: "500 ml" },
  { value: 750, label: "750 ml" },
  { value: 1000, label: "1 L" },
  { value: 1500, label: "1.5 L" },
  { value: 3000, label: "3 L" },
  { value: 5000, label: "5 L" },
  { value: 6000, label: "6 L" },
  { value: 9000, label: "9 L" },
  { value: 12000, label: "12 L" }
].freeze

DEFAULT_VOLUME = 750

VOLUMES.each do |volume|
  VolumeMl.find_or_create_by!(value: volume[:value]) do |v|
    v.label = volume[:label]
    v.is_default = (volume[:value] == DEFAULT_VOLUME)
  end
end

puts "Done. Seeded #{VolumeMl.count} volume_ml records."