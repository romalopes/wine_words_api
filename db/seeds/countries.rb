# Seed wine-producing countries and link grapes to their country of origin.
# Usage: rails runner db/seeds/countries.rb   (or require from db/seeds.rb)

Country.delete_all
ActiveRecord::Base.connection.reset_pk_sequence!('countries')

countries_data = [
  { name: "Argentina",      code: "AR", continent: "South America", flag_emoji: "🇦🇷" },
  { name: "Australia",      code: "AU", continent: "Oceania",       flag_emoji: "🇦🇺" },
  { name: "Austria",        code: "AT", continent: "Europe",        flag_emoji: "🇦🇹" },
  { name: "Chile",          code: "CL", continent: "South America", flag_emoji: "🇨🇱" },
  { name: "Croatia",        code: "HR", continent: "Europe",        flag_emoji: "🇭🇷" },
  { name: "France",         code: "FR", continent: "Europe",        flag_emoji: "🇫🇷" },
  { name: "Georgia",        code: "GE", continent: "Asia",          flag_emoji: "🇬🇪" },
  { name: "Germany",        code: "DE", continent: "Europe",        flag_emoji: "🇩🇪" },
  { name: "Greece",         code: "GR", continent: "Europe",        flag_emoji: "🇬🇷" },
  { name: "Hungary",        code: "HU", continent: "Europe",        flag_emoji: "🇭🇺" },
  { name: "Italy",          code: "IT", continent: "Europe",        flag_emoji: "🇮🇹" },
  { name: "New Zealand",    code: "NZ", continent: "Oceania",       flag_emoji: "🇳🇿" },
  { name: "Portugal",       code: "PT", continent: "Europe",        flag_emoji: "🇵🇹" },
  { name: "Romania",        code: "RO", continent: "Europe",        flag_emoji: "🇷🇴" },
  { name: "South Africa",   code: "ZA", continent: "Africa",        flag_emoji: "🇿🇦" },
  { name: "Spain",          code: "ES", continent: "Europe",        flag_emoji: "🇪🇸" },
  { name: "United States",  code: "US", continent: "North America", flag_emoji: "🇺🇸" },
  { name: "Brazil",         code: "BR", continent: "South America", flag_emoji: "🇧🇷" },
  { name: "Uruguay",        code: "UY", continent: "South America", flag_emoji: "🇺🇾" },
  { name: "Peru",           code: "PE", continent: "South America", flag_emoji: "🇵🇪" },
  { name: "Bolivia",        code: "BO", continent: "South America", flag_emoji: "🇧🇴" },
  { name: "Paraguay",       code: "PY", continent: "South America", flag_emoji: "🇵🇾" },
  { name: "Colombia",       code: "CO", continent: "South America", flag_emoji: "🇨🇴" },
  { name: "Canada",         code: "CA", continent: "North America", flag_emoji: "🇨🇦" },
  { name: "Mexico",         code: "MX", continent: "North America", flag_emoji: "🇲🇽" },
  { name: "Switzerland",    code: "CH", continent: "Europe",        flag_emoji: "🇨🇭" },
  { name: "England",        code: "GB", continent: "Europe",        flag_emoji: "🏴󠁧󠁢󠁥󠁮󠁧󠁿" },
  { name: "Luxembourg",     code: "LU", continent: "Europe",        flag_emoji: "🇱🇺" },
  { name: "Belgium",        code: "BE", continent: "Europe",        flag_emoji: "🇧🇪" },
  { name: "Bulgaria",       code: "BG", continent: "Europe",        flag_emoji: "🇧🇬" },
  { name: "Serbia",         code: "RS", continent: "Europe",        flag_emoji: "🇷🇸" },
  { name: "Slovenia",       code: "SI", continent: "Europe",        flag_emoji: "🇸🇮" },
  { name: "Slovakia",       code: "SK", continent: "Europe",        flag_emoji: "🇸🇰" },
  { name: "Czech Republic", code: "CZ", continent: "Europe",        flag_emoji: "🇨🇿" },
  { name: "Poland",         code: "PL", continent: "Europe",        flag_emoji: "🇵🇱" },
  { name: "Moldova",        code: "MD", continent: "Europe",        flag_emoji: "🇲🇩" },
  { name: "Ukraine",        code: "UA", continent: "Europe",        flag_emoji: "🇺🇦" },
  { name: "North Macedonia", code: "MK", continent: "Europe",       flag_emoji: "🇲🇰" },
  { name: "Montenegro",     code: "ME", continent: "Europe",        flag_emoji: "🇲🇪" },
  { name: "Bosnia and Herzegovina", code: "BA", continent: "Europe", flag_emoji: "🇧🇦" },
  { name: "Albania",        code: "AL", continent: "Europe",        flag_emoji: "🇦🇱" },
  { name: "Cyprus",         code: "CY", continent: "Europe",        flag_emoji: "🇨🇾" },
  { name: "Malta",          code: "MT", continent: "Europe",        flag_emoji: "🇲🇹" },
  { name: "Turkey",         code: "TR", continent: "Asia",          flag_emoji: "🇹🇷" },
  { name: "Lebanon",        code: "LB", continent: "Asia",          flag_emoji: "🇱🇧" },
  { name: "Israel",         code: "IL", continent: "Asia",          flag_emoji: "🇮🇱" },
  { name: "China",          code: "CN", continent: "Asia",          flag_emoji: "🇨🇳" },
  { name: "Japan",          code: "JP", continent: "Asia",          flag_emoji: "🇯🇵" },
  { name: "India",          code: "IN", continent: "Asia",          flag_emoji: "🇮🇳" },
  { name: "Morocco",        code: "MA", continent: "Africa",        flag_emoji: "🇲🇦" },
  { name: "Tunisia",        code: "TN", continent: "Africa",        flag_emoji: "🇹🇳" },
  { name: "Egypt",          code: "EG", continent: "Africa",        flag_emoji: "🇪🇬" },
  { name: "Ethiopia",       code: "ET", continent: "Africa",        flag_emoji: "🇪🇹" },
  { name: "Zimbabwe",       code: "ZW", continent: "Africa",        flag_emoji: "🇿🇼" },
  { name: "Namibia",        code: "NA", continent: "Africa",        flag_emoji: "🇳🇦" },
]

puts "Seeding countries..."
countries_data.each do |attrs|
  Country.find_or_create_by!(code: attrs[:code]) do |c|
    c.assign_attributes(attrs)
  end
end
puts "Done! #{Country.count} countries."

# Backfill grapes' country_id from their origin_country string
puts "Linking grapes to countries..."
grapes = Grape.where(country_id: nil)
count = 0
grapes.find_each do |grape|
  next if grape.origin_country.blank?
  country = Country.find_by("name ILIKE ?", grape.origin_country.strip)
  next unless country
  grape.update_column(:country_id, country.id) # rubocop:disable Rails/SkipsModelValidations
  count += 1
end
puts "Linked #{count} grapes to countries."
