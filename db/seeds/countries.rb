# Seed wine-producing countries and link grapes to their country of origin.
# Then seed the rest of the world's countries (population > 1 million) as
# non-wine-producing entries, so the Country table covers every populous
# country while still flagging which ones are recognized wine countries.
# Usage: rails runner db/seeds/countries.rb   (or require from db/seeds.rb)

# Existing wine-producing countries
wine_countries_data = [
  { name: "Argentina",      code: "AR", continent: "South America", flag_emoji: "🇦🇷", is_wine_country: true },
  { name: "Australia",      code: "AU", continent: "Oceania",       flag_emoji: "🇦🇺", is_wine_country: true },
  { name: "Austria",        code: "AT", continent: "Europe",        flag_emoji: "🇦🇹", is_wine_country: true },
  { name: "Chile",          code: "CL", continent: "South America", flag_emoji: "🇨🇱", is_wine_country: true },
  { name: "Croatia",        code: "HR", continent: "Europe",        flag_emoji: "🇭🇷", is_wine_country: false },
  { name: "France",         code: "FR", continent: "Europe",        flag_emoji: "🇫🇷", is_wine_country: false },
  { name: "Georgia",        code: "GE", continent: "Asia",          flag_emoji: "🇬🇪", is_wine_country: false },
  { name: "Germany",        code: "DE", continent: "Europe",        flag_emoji: "🇩🇪", is_wine_country: true },
  { name: "Greece",         code: "GR", continent: "Europe",        flag_emoji: "🇬🇷", is_wine_country: true },
  { name: "Hungary",        code: "HU", continent: "Europe",        flag_emoji: "🇭🇺", is_wine_country: false },
  { name: "Italy",          code: "IT", continent: "Europe",        flag_emoji: "🇮🇹", is_wine_country: true },
  { name: "New Zealand",    code: "NZ", continent: "Oceania",       flag_emoji: "🇳🇿", is_wine_country: true },
  { name: "Portugal",       code: "PT", continent: "Europe",        flag_emoji: "🇵🇹", is_wine_country: true },
  { name: "Romania",        code: "RO", continent: "Europe",        flag_emoji: "🇷🇴", is_wine_country: false },
  { name: "South Africa",   code: "ZA", continent: "Africa",        flag_emoji: "🇿🇦", is_wine_country: true },
  { name: "Spain",          code: "ES", continent: "Europe",        flag_emoji: "🇪🇸", is_wine_country: true },
  { name: "United States",  code: "US", continent: "North America", flag_emoji: "🇺🇸", is_wine_country: true },
  { name: "Brazil",         code: "BR", continent: "South America", flag_emoji: "🇧🇷", is_wine_country: true },
  { name: "Uruguay",        code: "UY", continent: "South America", flag_emoji: "🇺🇾", is_wine_country: false },
  { name: "Peru",           code: "PE", continent: "South America", flag_emoji: "🇵🇪", is_wine_country: false },
  { name: "Bolivia",        code: "BO", continent: "South America", flag_emoji: "🇧🇴", is_wine_country: false },
  { name: "Paraguay",       code: "PY", continent: "South America", flag_emoji: "🇵🇾", is_wine_country: false },
  { name: "Colombia",       code: "CO", continent: "South America", flag_emoji: "🇨🇴", is_wine_country: false },
  { name: "Canada",         code: "CA", continent: "North America", flag_emoji: "🇨🇦", is_wine_country: true },
  { name: "Mexico",         code: "MX", continent: "North America", flag_emoji: "🇲🇽", is_wine_country: true },
  { name: "Switzerland",    code: "CH", continent: "Europe",        flag_emoji: "🇨🇭", is_wine_country: true },
  { name: "England",        code: "GB", continent: "Europe",        flag_emoji: "🏴󠁧󠁢󠁥󠁮󠁧󠁿", is_wine_country: true },
  { name: "Luxembourg",     code: "LU", continent: "Europe",        flag_emoji: "🇱🇺", is_wine_country: false },
  { name: "Belgium",        code: "BE", continent: "Europe",        flag_emoji: "🇧🇪", is_wine_country: true },
  { name: "Bulgaria",       code: "BG", continent: "Europe",        flag_emoji: "🇧🇬", is_wine_country: true },
  { name: "Serbia",         code: "RS", continent: "Europe",        flag_emoji: "🇷🇸", is_wine_country: true },
  { name: "Slovenia",       code: "SI", continent: "Europe",        flag_emoji: "🇸🇮", is_wine_country: true },
  { name: "Slovakia",       code: "SK", continent: "Europe",        flag_emoji: "🇸🇰", is_wine_country: true },
  { name: "Czech Republic", code: "CZ", continent: "Europe",        flag_emoji: "🇨🇿", is_wine_country: true },
  { name: "Poland",         code: "PL", continent: "Europe",        flag_emoji: "🇵🇱", is_wine_country: true },
  { name: "Moldova",        code: "MD", continent: "Europe",        flag_emoji: "🇲🇩", is_wine_country: true },
  { name: "Ukraine",        code: "UA", continent: "Europe",        flag_emoji: "🇺🇦", is_wine_country: true },
  { name: "North Macedonia", code: "MK", continent: "Europe",       flag_emoji: "🇲🇰", is_wine_country: true },
  { name: "Montenegro",     code: "ME", continent: "Europe",        flag_emoji: "🇲🇪", is_wine_country: true },
  { name: "Bosnia and Herzegovina", code: "BA", continent: "Europe", flag_emoji: "🇧🇦", is_wine_country: true },
  { name: "Albania",        code: "AL", continent: "Europe",        flag_emoji: "🇦🇱", is_wine_country: true },
  { name: "Cyprus",         code: "CY", continent: "Europe",        flag_emoji: "🇨🇾", is_wine_country: true },
  { name: "Malta",          code: "MT", continent: "Europe",        flag_emoji: "🇲🇹", is_wine_country: true },
  { name: "Turkey",         code: "TR", continent: "Asia",          flag_emoji: "🇹🇷", is_wine_country: true },
  { name: "Lebanon",        code: "LB", continent: "Asia",          flag_emoji: "🇱🇧", is_wine_country: true },
  { name: "Israel",         code: "IL", continent: "Asia",          flag_emoji: "🇮🇱", is_wine_country: false },
  { name: "China",          code: "CN", continent: "Asia",          flag_emoji: "🇨🇳", is_wine_country: true },
  { name: "Japan",          code: "JP", continent: "Asia",          flag_emoji: "🇯🇵", is_wine_country: true },
  { name: "India",          code: "IN", continent: "Asia",          flag_emoji: "🇮🇳", is_wine_country: true },
  { name: "Morocco",        code: "MA", continent: "Africa",        flag_emoji: "🇲🇦", is_wine_country: true },
  { name: "Tunisia",        code: "TN", continent: "Africa",        flag_emoji: "🇹🇳", is_wine_country: false },
  { name: "Egypt",          code: "EG", continent: "Africa",        flag_emoji: "🇪🇬", is_wine_country: true },
  { name: "Ethiopia",       code: "ET", continent: "Africa",        flag_emoji: "🇪🇹", is_wine_country: false },
  { name: "Zimbabwe",       code: "ZW", continent: "Africa",        flag_emoji: "🇿🇼", is_wine_country: false },
  { name: "Namibia",        code: "NA", continent: "Africa",        flag_emoji: "🇳🇦", is_wine_country: false },
]

# Remaining countries of the world with population > 1 million that are not
# already covered above. Not flagged as wine-producing countries.
other_countries_data = [
  # Africa
  { name: "Algeria",                    code: "DZ", continent: "Africa", flag_emoji: "🇩🇿", is_wine_country: false },
  { name: "Angola",                     code: "AO", continent: "Africa", flag_emoji: "🇦🇴", is_wine_country: false },
  { name: "Benin",                      code: "BJ", continent: "Africa", flag_emoji: "🇧🇯", is_wine_country: false },
  { name: "Botswana",                   code: "BW", continent: "Africa", flag_emoji: "🇧🇼", is_wine_country: false },
  { name: "Burkina Faso",               code: "BF", continent: "Africa", flag_emoji: "🇧🇫", is_wine_country: false },
  { name: "Burundi",                    code: "BI", continent: "Africa", flag_emoji: "🇧🇮", is_wine_country: false },
  { name: "Cameroon",                   code: "CM", continent: "Africa", flag_emoji: "🇨🇲", is_wine_country: false },
  { name: "Central African Republic",   code: "CF", continent: "Africa", flag_emoji: "🇨🇫", is_wine_country: false },
  { name: "Chad",                       code: "TD", continent: "Africa", flag_emoji: "🇹🇩", is_wine_country: false },
  { name: "Congo (DRC)",                code: "CD", continent: "Africa", flag_emoji: "🇨🇩", is_wine_country: false },
  { name: "Congo (Republic)",           code: "CG", continent: "Africa", flag_emoji: "🇨🇬", is_wine_country: false },
  { name: "Djibouti",                   code: "DJ", continent: "Africa", flag_emoji: "🇩🇯", is_wine_country: false },
  { name: "Equatorial Guinea",          code: "GQ", continent: "Africa", flag_emoji: "🇬🇶", is_wine_country: false },
  { name: "Eritrea",                    code: "ER", continent: "Africa", flag_emoji: "🇪🇷", is_wine_country: false },
  { name: "Eswatini",                   code: "SZ", continent: "Africa", flag_emoji: "🇸🇿", is_wine_country: false },
  { name: "Gabon",                      code: "GA", continent: "Africa", flag_emoji: "🇬🇦", is_wine_country: false },
  { name: "Gambia",                     code: "GM", continent: "Africa", flag_emoji: "🇬🇲", is_wine_country: false },
  { name: "Ghana",                      code: "GH", continent: "Africa", flag_emoji: "🇬🇭", is_wine_country: false },
  { name: "Guinea",                     code: "GN", continent: "Africa", flag_emoji: "🇬🇳", is_wine_country: false },
  { name: "Guinea-Bissau",              code: "GW", continent: "Africa", flag_emoji: "🇬🇼", is_wine_country: false },
  { name: "Ivory Coast",                code: "CI", continent: "Africa", flag_emoji: "🇨🇮", is_wine_country: false },
  { name: "Kenya",                      code: "KE", continent: "Africa", flag_emoji: "🇰🇪", is_wine_country: false },
  { name: "Lesotho",                    code: "LS", continent: "Africa", flag_emoji: "🇱🇸", is_wine_country: false },
  { name: "Liberia",                    code: "LR", continent: "Africa", flag_emoji: "🇱🇷", is_wine_country: false },
  { name: "Libya",                      code: "LY", continent: "Africa", flag_emoji: "🇱🇾", is_wine_country: false },
  { name: "Madagascar",                 code: "MG", continent: "Africa", flag_emoji: "🇲🇬", is_wine_country: false },
  { name: "Malawi",                     code: "MW", continent: "Africa", flag_emoji: "🇲🇼", is_wine_country: false },
  { name: "Mali",                       code: "ML", continent: "Africa", flag_emoji: "🇲🇱", is_wine_country: false },
  { name: "Mauritania",                 code: "MR", continent: "Africa", flag_emoji: "🇲🇷", is_wine_country: false },
  { name: "Mauritius",                  code: "MU", continent: "Africa", flag_emoji: "🇲🇺", is_wine_country: false },
  { name: "Mozambique",                 code: "MZ", continent: "Africa", flag_emoji: "🇲🇿", is_wine_country: false },
  { name: "Niger",                      code: "NE", continent: "Africa", flag_emoji: "🇳🇪", is_wine_country: false },
  { name: "Nigeria",                    code: "NG", continent: "Africa", flag_emoji: "🇳🇬", is_wine_country: false },
  { name: "Rwanda",                     code: "RW", continent: "Africa", flag_emoji: "🇷🇼", is_wine_country: false },
  { name: "Senegal",                    code: "SN", continent: "Africa", flag_emoji: "🇸🇳", is_wine_country: false },
  { name: "Sierra Leone",               code: "SL", continent: "Africa", flag_emoji: "🇸🇱", is_wine_country: false },
  { name: "Somalia",                    code: "SO", continent: "Africa", flag_emoji: "🇸🇴", is_wine_country: false },
  { name: "South Sudan",                code: "SS", continent: "Africa", flag_emoji: "🇸🇸", is_wine_country: false },
  { name: "Sudan",                      code: "SD", continent: "Africa", flag_emoji: "🇸🇩", is_wine_country: false },
  { name: "Tanzania",                   code: "TZ", continent: "Africa", flag_emoji: "🇹🇿", is_wine_country: false },
  { name: "Togo",                       code: "TG", continent: "Africa", flag_emoji: "🇹🇬", is_wine_country: false },
  { name: "Uganda",                     code: "UG", continent: "Africa", flag_emoji: "🇺🇬", is_wine_country: false },
  { name: "Zambia",                     code: "ZM", continent: "Africa", flag_emoji: "🇿🇲", is_wine_country: false },

  # Americas
  { name: "Costa Rica",                 code: "CR", continent: "North America", flag_emoji: "🇨🇷", is_wine_country: false },
  { name: "El Salvador",                code: "SV", continent: "North America", flag_emoji: "🇸🇻", is_wine_country: false },
  { name: "Guatemala",                  code: "GT", continent: "North America", flag_emoji: "🇬🇹", is_wine_country: false },
  { name: "Honduras",                   code: "HN", continent: "North America", flag_emoji: "🇭🇳", is_wine_country: false },
  { name: "Nicaragua",                  code: "NI", continent: "North America", flag_emoji: "🇳🇮", is_wine_country: false },
  { name: "Panama",                     code: "PA", continent: "North America", flag_emoji: "🇵🇦", is_wine_country: false },
  { name: "Cuba",                       code: "CU", continent: "North America", flag_emoji: "🇨🇺", is_wine_country: false },
  { name: "Dominican Republic",         code: "DO", continent: "North America", flag_emoji: "🇩🇴", is_wine_country: false },
  { name: "Haiti",                      code: "HT", continent: "North America", flag_emoji: "🇭🇹", is_wine_country: false },
  { name: "Jamaica",                    code: "JM", continent: "North America", flag_emoji: "🇯🇲", is_wine_country: false },
  { name: "Trinidad and Tobago",        code: "TT", continent: "North America", flag_emoji: "🇹🇹", is_wine_country: false },
  { name: "Ecuador",                    code: "EC", continent: "South America", flag_emoji: "🇪🇨", is_wine_country: false },
  { name: "Venezuela",                  code: "VE", continent: "South America", flag_emoji: "🇻🇪", is_wine_country: false },

  # Asia
  { name: "Afghanistan",                code: "AF", continent: "Asia", flag_emoji: "🇦🇫", is_wine_country: false },
  { name: "Armenia",                    code: "AM", continent: "Asia", flag_emoji: "🇦🇲", is_wine_country: false },
  { name: "Azerbaijan",                 code: "AZ", continent: "Asia", flag_emoji: "🇦🇿", is_wine_country: false },
  { name: "Bahrain",                    code: "BH", continent: "Asia", flag_emoji: "🇧🇭", is_wine_country: false },
  { name: "Bangladesh",                 code: "BD", continent: "Asia", flag_emoji: "🇧🇩", is_wine_country: false },
  { name: "Cambodia",                   code: "KH", continent: "Asia", flag_emoji: "🇰🇭", is_wine_country: false },
  { name: "Indonesia",                  code: "ID", continent: "Asia", flag_emoji: "🇮🇩", is_wine_country: false },
  { name: "Iran",                       code: "IR", continent: "Asia", flag_emoji: "🇮🇷", is_wine_country: false },
  { name: "Iraq",                       code: "IQ", continent: "Asia", flag_emoji: "🇮🇶", is_wine_country: false },
  { name: "Jordan",                     code: "JO", continent: "Asia", flag_emoji: "🇯🇴", is_wine_country: false },
  { name: "Kazakhstan",                 code: "KZ", continent: "Asia", flag_emoji: "🇰🇿", is_wine_country: false },
  { name: "Kuwait",                     code: "KW", continent: "Asia", flag_emoji: "🇰🇼", is_wine_country: false },
  { name: "Kyrgyzstan",                 code: "KG", continent: "Asia", flag_emoji: "🇰🇬", is_wine_country: false },
  { name: "Laos",                       code: "LA", continent: "Asia", flag_emoji: "🇱🇦", is_wine_country: false },
  { name: "Malaysia",                   code: "MY", continent: "Asia", flag_emoji: "🇲🇾", is_wine_country: false },
  { name: "Mongolia",                   code: "MN", continent: "Asia", flag_emoji: "🇲🇳", is_wine_country: false },
  { name: "Myanmar",                    code: "MM", continent: "Asia", flag_emoji: "🇲🇲", is_wine_country: false },
  { name: "Nepal",                      code: "NP", continent: "Asia", flag_emoji: "🇳🇵", is_wine_country: false },
  { name: "North Korea",                code: "KP", continent: "Asia", flag_emoji: "🇰🇵", is_wine_country: false },
  { name: "Oman",                       code: "OM", continent: "Asia", flag_emoji: "🇴🇲", is_wine_country: false },
  { name: "Pakistan",                   code: "PK", continent: "Asia", flag_emoji: "🇵🇰", is_wine_country: false },
  { name: "Palestine",                  code: "PS", continent: "Asia", flag_emoji: "🇵🇸", is_wine_country: false },
  { name: "Philippines",                code: "PH", continent: "Asia", flag_emoji: "🇵🇭", is_wine_country: false },
  { name: "Qatar",                      code: "QA", continent: "Asia", flag_emoji: "🇶🇦", is_wine_country: false },
  { name: "Saudi Arabia",               code: "SA", continent: "Asia", flag_emoji: "🇸🇦", is_wine_country: false },
  { name: "Singapore",                  code: "SG", continent: "Asia", flag_emoji: "🇸🇬", is_wine_country: false },
  { name: "South Korea",                code: "KR", continent: "Asia", flag_emoji: "🇰🇷", is_wine_country: false },
  { name: "Sri Lanka",                  code: "LK", continent: "Asia", flag_emoji: "🇱🇰", is_wine_country: false },
  { name: "Syria",                      code: "SY", continent: "Asia", flag_emoji: "🇸🇾", is_wine_country: false },
  { name: "Taiwan",                     code: "TW", continent: "Asia", flag_emoji: "🇹🇼", is_wine_country: false },
  { name: "Tajikistan",                 code: "TJ", continent: "Asia", flag_emoji: "🇹🇯", is_wine_country: false },
  { name: "Thailand",                   code: "TH", continent: "Asia", flag_emoji: "🇹🇭", is_wine_country: false },
  { name: "Timor-Leste",                code: "TL", continent: "Asia", flag_emoji: "🇹🇱", is_wine_country: false },
  { name: "Turkmenistan",               code: "TM", continent: "Asia", flag_emoji: "🇹🇲", is_wine_country: false },
  { name: "United Arab Emirates",       code: "AE", continent: "Asia", flag_emoji: "🇦🇪", is_wine_country: false },
  { name: "Uzbekistan",                 code: "UZ", continent: "Asia", flag_emoji: "🇺🇿", is_wine_country: false },
  { name: "Vietnam",                    code: "VN", continent: "Asia", flag_emoji: "🇻🇳", is_wine_country: false },
  { name: "Yemen",                      code: "YE", continent: "Asia", flag_emoji: "🇾🇪", is_wine_country: false },

  # Europe
  { name: "Belarus",                    code: "BY", continent: "Europe", flag_emoji: "🇧🇾", is_wine_country: false },
  { name: "Denmark",                    code: "DK", continent: "Europe", flag_emoji: "🇩🇰", is_wine_country: false },
  { name: "Estonia",                    code: "EE", continent: "Europe", flag_emoji: "🇪🇪", is_wine_country: false },
  { name: "Finland",                    code: "FI", continent: "Europe", flag_emoji: "🇫🇮", is_wine_country: false },
  { name: "Ireland",                    code: "IE", continent: "Europe", flag_emoji: "🇮🇪", is_wine_country: false },
  { name: "Latvia",                     code: "LV", continent: "Europe", flag_emoji: "🇱🇻", is_wine_country: false },
  { name: "Lithuania",                  code: "LT", continent: "Europe", flag_emoji: "🇱🇹", is_wine_country: false },
  { name: "Netherlands",                code: "NL", continent: "Europe", flag_emoji: "🇳🇱", is_wine_country: false },
  { name: "Norway",                     code: "NO", continent: "Europe", flag_emoji: "🇳🇴", is_wine_country: false },
  { name: "Russia",                     code: "RU", continent: "Europe", flag_emoji: "🇷🇺", is_wine_country: false },
  { name: "Sweden",                     code: "SE", continent: "Europe", flag_emoji: "🇸🇪", is_wine_country: false },

  # Oceania
  { name: "Papua New Guinea",           code: "PG", continent: "Oceania", flag_emoji: "🇵🇬", is_wine_country: false },
]

countries_data = wine_countries_data + other_countries_data

puts "Seeding countries..."
countries_data.each do |attrs|
  Country.find_or_create_by!(name: attrs[:name], code: attrs[:code]) do |c|
    c.assign_attributes(attrs)
  end
  c = Country.find_by_code(attrs[:code])
  c.update(is_wine_country: attrs[:is_wine_country]) if c.is_wine_country != attrs[:is_wine_country]
end

puts "Done! #{Country.count} countries."

# # Backfill grapes' country_id from their origin_country string
# puts "Linking grapes to countries..."
# grapes = Grape.where(country_id: nil)
# count = 0
# grapes.find_each do |grape|
#   next if grape.origin_country.blank?
#   country = Country.find_by("name ILIKE ?", grape.origin_country.strip)
#   next unless country
#   grape.update_column(:country_id, country.id) # rubocop:disable Rails/SkipsModelValidations
#   count += 1
# end
# puts "Linked #{count} grapes to countries."