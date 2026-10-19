# db/seeds/wine_profiles.rb
# Seed data for wine profiles using associations with grapes and regions
# Run with: rails db:seed:wine_profiles

# Extract the p hash from the existing seeds.rb for taste parameters
# We'll define it here as well to avoid dependency
p = {
  pinotNoir: { acidity: 4, body: 2, tannin: 2, sweetness: 1, alcohol: 2, fruit: 3 },
  cab: { acidity: 3, body: 5, tannin: 5, sweetness: 1, alcohol: 4, fruit: 4 },
  merlot: { acidity: 3, body: 4, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 },
  syrah: { acidity: 3, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 5 },
  sangiovese: { acidity: 5, body: 3, tannin: 4, sweetness: 1, alcohol: 3, fruit: 3 },
  chardonnay: { acidity: 3, body: 4, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  sauvBlanc: { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 4 },
  riesling: { acidity: 5, body: 2, tannin: 1, sweetness: 3, alcohol: 2, fruit: 4 },
  prosecco: { acidity: 4, body: 1, tannin: 1, sweetness: 2, alcohol: 1, fruit: 4 },
  rose: { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  tempranillo: { acidity: 4, body: 4, tannin: 4, sweetness: 1, alcohol: 3, fruit: 4 },
  malbec: { acidity: 3, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 5 },
  zinfandel: { acidity: 3, body: 5, tannin: 4, sweetness: 2, alcohol: 5, fruit: 5 },
  nebbiolo: { acidity: 4, body: 4, tannin: 5, sweetness: 1, alcohol: 4, fruit: 3 },
  gamay: { acidity: 4, body: 2, tannin: 2, sweetness: 1, alcohol: 2, fruit: 4 },
  pinotGrigio: { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  pinotGris: { acidity: 3, body: 3, tannin: 1, sweetness: 2, alcohol: 3, fruit: 4 },
  viognier: { acidity: 3, body: 4, tannin: 1, sweetness: 3, alcohol: 3, fruit: 4 },
  gewurz: { acidity: 3, body: 4, tannin: 1, sweetness: 3, alcohol: 4, fruit: 5 },
  chenin: { acidity: 5, body: 3, tannin: 1, sweetness: 2, alcohol: 2, fruit: 3 },
  semillon: { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 2 },
  gruner: { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  albarino: { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 4 },
  verdejo: { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  champagne: { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  cava: { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  franciacorta: { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  moscato: { acidity: 4, body: 2, tannin: 1, sweetness: 5, alcohol: 1, fruit: 5 },
  sauternes: { acidity: 4, body: 4, tannin: 1, sweetness: 5, alcohol: 3, fruit: 5 },
  port: { acidity: 3, body: 4, tannin: 3, sweetness: 5, alcohol: 4, fruit: 4 },
  sherry: { acidity: 3, body: 4, tannin: 1, sweetness: 2, alcohol: 5, fruit: 3 },
  pinotage: { acidity: 3, body: 4, tannin: 3, sweetness: 1, alcohol: 4, fruit: 4 },
  torrontes: { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 3, fruit: 5 },
  superTuscan: { acidity: 4, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 4 }
}

# Wine profiles data with grape and region names
# Wine profiles data with grape and region names
wine_profiles_data = [
  {
    name: "Classic Cabernet Sauvignon",
    slug: "classic-cabernet-sauvignon",
    color: "red",
    notes: "A full-bodied red with blackcurrant and cedar notes.",
    serving: "Best served at 16-18°C",
    grape_names: ["Cabernet Sauvignon"],
    region_names: ["Bordeaux"],
    parameters: p[:cab]
  },
  {
    name: "Elegant Pinot Noir",
    slug: "elegant-pinot-noir",
    color: "red",
    notes: "A light to medium bodied red with red fruit and earthy notes.",
    serving: "Best served at 14-16°C",
    grape_names: ["Pinot Noir"],
    region_names: ["Burgundy"],
    parameters: p[:pinotNoir]
  },
  {
    name: "Rich Chardonnay",
    slug: "rich-chardonnay",
    color: "white",
    notes: "A full-bodied white with citrus, butter, and oak notes.",
    serving: "Best served at 10-12°C",
    grape_names: ["Chardonnay"],
    region_names: ["California"],
    parameters: p[:chardonnay]
  },
  {
    name: "Zesty Sauvignon Blanc",
    slug: "zesty-sauvignon-blanc",
    color: "white",
    notes: "A crisp white with citrus, herbal, and tropical fruit notes.",
    serving: "Best served at 8-10°C",
    grape_names: ["Sauvignon Blanc"],
    region_names: ["Marlborough"],
    parameters: p[:sauvBlanc]
  },
  {
    name: "Spicy Syrah",
    slug: "spicy-syrah",
    color: "red",
    notes: "A full-bodied red with dark fruit, pepper, and spice notes.",
    serving: "Best served at 16-18°C",
    grape_names: ["Syrah"],
    region_names: ["Rhône Valley"],
    parameters: p[:syrah]
  }
]

# Create wine profiles and associate grapes and regions
wine_profiles_data.each do |profile_data|
  grape_names = profile_data.delete(:grape_names)
  region_names = profile_data.delete(:region_names)

  wine_profile = WineProfile.create!(profile_data)

  # Associate grapes
  grape_names.each do |grape_name|
    grape = Grape.find_by(name: grape_name)
    if grape
      wine_profile.profile_grapes << grape
    else
      puts "Warning: Grape \"#{grape_name}\" not found. Skipping association."
    end
  end

  # Associate regions
  region_names.each do |region_name|
    region = Region.where("name ILIKE ?", region_name).first
    if region
      wine_profile.profile_regions << region
    else
      puts "Warning: Region \"#{region_name}\" not found. Skipping association."
    end
  end
end

puts "Created #{WineProfile.count} wine profile records."