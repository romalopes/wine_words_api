# db/seeds/regions.rb
# Seeds wine regions and links them to countries.
# Usage: rails runner db/seeds/regions.rb
# Populates Region records with name, country_id, parent_id, is_state, is_appellation.

puts "Seeding regions..."

# Top-level regions: [name, country_name, is_state, is_appellation]
TOP = [
  # France
  ["Burgundy", "France", false, true], ["Bordeaux", "France", false, true],
  ["Rhône Valley", "France", false, true], ["Champagne", "France", true, false],
  ["Loire Valley", "France", false, true], ["Alsace", "France", true, true],
  ["Provence", "France", true, true], ["Jura", "France", true, true],
  # Italy
  ["Tuscany", "Italy", false, true], ["Piedmont", "Italy", false, true],
  ["Veneto", "Italy", true, true], ["Sicily", "Italy", true, true],
  ["Puglia", "Italy", true, true], ["Lombardy", "Italy", true, true],
  # Spain
  ["Rioja", "Spain", false, true], ["Ribera del Duero", "Spain", false, true],
  ["Priorat", "Spain", false, true], ["Rías Baixas", "Spain", false, true],
  ["Rueda", "Spain", false, true], ["Catalonia", "Spain", true, true],
  # Portugal
  ["Douro", "Portugal", false, true], ["Dão", "Portugal", false, true],
  ["Alentejo", "Portugal", true, true], ["Vinho Verde", "Portugal", true, true],
  ["Bairrada", "Portugal", false, true],
  # Greece
  ["Nemea", "Greece", false, true], ["Santorini", "Greece", true, true],
  ["Naoussa", "Greece", false, true],
  # Austria & Central Europe
  ["Wachau", "Austria", false, true], ["Kamptal", "Austria", false, true],
  ["Burgenland", "Austria", true, true], ["Tokaj", "Hungary", false, true],
  ["Villány", "Hungary", false, true],
  # New World
  ["Napa Valley", "United States", true, true], ["Sonoma County", "United States", true, true],
  ["Central Coast", "United States", true, false], ["Oregon", "United States", true, true],
  ["Marlborough", "New Zealand", false, true], ["Central Otago", "New Zealand", false, true],
  ["Barossa Valley", "Australia", false, true], ["McLaren Vale", "Australia", false, true],
  ["Hunter Valley", "Australia", false, true], ["Mendoza", "Argentina", true, true],
  ["Maipo Valley", "Chile", false, true], ["Colchagua Valley", "Chile", false, true],
  ["Stellenbosch", "South Africa", false, true], ["Paarl", "South Africa", false, true],
  ["Serra Gaúcha", "Brazil", true, true],
]
# Sub-regions: [name, country_name, parent_name, is_state, is_appellation]
SUB = [
  ["Côte de Nuits", "France", "Burgundy", false, true],
  ["Côte de Beaune", "France", "Burgundy", false, true],
  ["Médoc", "France", "Bordeaux", false, true],
  ["Pomerol", "France", "Bordeaux", false, true],
  ["Chianti Classico", "Italy", "Tuscany", false, true],
  ["Barolo", "Italy", "Piedmont", false, true],
  ["Rioja Alavesa", "Spain", "Rioja", false, true],
]

# Create top-level regions
TOP.each do |name, country_name, is_state, is_appellation|
  country = Country.find_by(name: country_name)
  next unless country
  Region.find_or_create_by!(name: name, country: country) do |r|
    r.is_state = is_state
    r.is_appellation = is_appellation
  end
end

# Create sub-regions with parent_id
SUB.each do |name, country_name, parent_name, is_state, is_appellation|
  country = Country.find_by(name: country_name)
  parent = country && Region.find_by(name: parent_name, country: country)
  next unless country && parent
  Region.find_or_create_by!(name: name, country: country, parent: parent) do |r|
    r.is_state = is_state
    r.is_appellation = is_appellation
  end
end

puts "Done! #{Region.count} regions seeded."