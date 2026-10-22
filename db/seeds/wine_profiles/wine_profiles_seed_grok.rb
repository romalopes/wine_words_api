# db/seeds/wine_profiles_seed_claude.rb
# Comprehensive wine profiles covering major grape varieties.
# Includes all existing profiles from db/seeds.rb plus additional
# major red, white, sparkling, and dessert varieties.
#
# Usage (from Rails root):
#   rails runner db/seeds/wine_profiles_seed_claude.rb
# or require it from seeds.rb:
#   require_relative "seeds/wine_profiles_seed_claude"
#
# Idempotent: destroys existing WineProfile / WineProfileTasteParameter
# (and TasteParameter if you want a clean slate) before recreating.

# ---------------------------------------------------------------------------
# Optional clean slate (comment out if you prefer to keep other seeded data)
# ---------------------------------------------------------------------------
WineProfileTasteParameter.destroy_all
WineProfile.destroy_all
# Uncomment the next two lines only if you also want to re-seed taste parameters:
# TasteParameter.destroy_all
# ActiveRecord::Base.connection.reset_pk_sequence!("taste_parameters")

ActiveRecord::Base.connection.reset_pk_sequence!("wine_profiles")
ActiveRecord::Base.connection.reset_pk_sequence!("wine_profile_taste_parameters")

# ---------------------------------------------------------------------------
# Taste parameters (create only if missing)
# ---------------------------------------------------------------------------
taste_params_data = [
  { slug: "acidity",  label: "Acidity",         low: "Soft",    high: "Sharp",      help: "How bright, fresh, or mouth-watering the wine feels." },
  { slug: "body",     label: "Body",            low: "Light",   high: "Full",       help: "The weight and richness of the wine on your palate." },
  { slug: "tannin",   label: "Tannin",          low: "Silky",   high: "Grippy",     help: "The drying texture, common in red wines." },
  { slug: "sweetness",label: "Sweetness",       low: "Dry",     high: "Sweet",      help: "How much sugar or ripe sweetness you perceive." },
  { slug: "alcohol",  label: "Alcohol warmth",  low: "Cool",    high: "Warm",       help: "The heat or weight from alcohol." },
  { slug: "fruit",    label: "Fruit intensity", low: "Subtle",  high: "Expressive", help: "How strongly fruit aromas and flavors stand out." }
]

taste_params_data.each do |tp|
  TasteParameter.find_or_create_by!(slug: tp[:slug]) do |record|
    record.label = tp[:label]
    record.low   = tp[:low]
    record.high  = tp[:high]
    record.help  = tp[:help]
  end
end

# ---------------------------------------------------------------------------
# Taste parameter scores (1–5 scale) keyed for each profile
# ---------------------------------------------------------------------------
p = {
  # --- Existing profiles ---
  pinotNoir:    { acidity: 4, body: 2, tannin: 2, sweetness: 1, alcohol: 2, fruit: 3 },
  cab:          { acidity: 3, body: 5, tannin: 5, sweetness: 1, alcohol: 4, fruit: 4 },
  merlot:       { acidity: 3, body: 4, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 },
  syrah:        { acidity: 3, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 5 },
  sangiovese:   { acidity: 5, body: 3, tannin: 4, sweetness: 1, alcohol: 3, fruit: 3 },
  chardonnay:   { acidity: 3, body: 4, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  sauvBlanc:    { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 4 },
  riesling:     { acidity: 5, body: 2, tannin: 1, sweetness: 3, alcohol: 2, fruit: 4 },
  prosecco:     { acidity: 4, body: 1, tannin: 1, sweetness: 2, alcohol: 1, fruit: 4 },
  rose:         { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  tempranillo:  { acidity: 4, body: 4, tannin: 4, sweetness: 1, alcohol: 3, fruit: 4 },
  malbec:       { acidity: 3, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 5 },
  zinfandel:    { acidity: 3, body: 5, tannin: 4, sweetness: 2, alcohol: 5, fruit: 5 },
  nebbiolo:     { acidity: 4, body: 4, tannin: 5, sweetness: 1, alcohol: 4, fruit: 3 },
  gamay:        { acidity: 4, body: 2, tannin: 2, sweetness: 1, alcohol: 2, fruit: 4 },
  pinotGrigio:  { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  pinotGris:    { acidity: 3, body: 3, tannin: 1, sweetness: 2, alcohol: 3, fruit: 4 },
  viognier:     { acidity: 3, body: 4, tannin: 1, sweetness: 2, alcohol: 4, fruit: 5 },
  gewurz:       { acidity: 3, body: 4, tannin: 1, sweetness: 3, alcohol: 4, fruit: 5 },
  chenin:       { acidity: 5, body: 3, tannin: 1, sweetness: 2, alcohol: 2, fruit: 3 },
  semillon:     { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 2 },
  gruner:       { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  albarino:     { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 4 },
  verdejo:      { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  champagne:    { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  cava:         { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  franciacorta: { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  moscato:      { acidity: 4, body: 2, tannin: 1, sweetness: 5, alcohol: 1, fruit: 5 },
  sauternes:    { acidity: 4, body: 4, tannin: 1, sweetness: 5, alcohol: 3, fruit: 5 },
  port:         { acidity: 3, body: 4, tannin: 3, sweetness: 5, alcohol: 4, fruit: 4 },
  sherry:       { acidity: 3, body: 4, tannin: 1, sweetness: 2, alcohol: 5, fruit: 3 },
  pinotage:     { acidity: 3, body: 4, tannin: 3, sweetness: 1, alcohol: 4, fruit: 4 },
  torrontes:    { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 3, fruit: 5 },
  superTuscan:  { acidity: 4, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 4 },

  # --- New red varieties ---
  grenache:       { acidity: 3, body: 4, tannin: 2, sweetness: 1, alcohol: 4, fruit: 5 },
  cabFranc:       { acidity: 4, body: 3, tannin: 3, sweetness: 1, alcohol: 3, fruit: 3 },
  carmenere:      { acidity: 3, body: 4, tannin: 3, sweetness: 1, alcohol: 4, fruit: 4 },
  mourvedre:      { acidity: 3, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 4 },
  barbera:        { acidity: 5, body: 3, tannin: 2, sweetness: 1, alcohol: 3, fruit: 4 },
  dolcetto:       { acidity: 3, body: 3, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 },
  montepulciano:  { acidity: 4, body: 4, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 },
  aglianico:      { acidity: 4, body: 5, tannin: 5, sweetness: 1, alcohol: 4, fruit: 3 },
  neroDAvola:     { acidity: 3, body: 4, tannin: 3, sweetness: 1, alcohol: 4, fruit: 5 },
  primitivo:      { acidity: 3, body: 5, tannin: 3, sweetness: 2, alcohol: 5, fruit: 5 },
  tourigaNacional:{ acidity: 3, body: 5, tannin: 5, sweetness: 1, alcohol: 4, fruit: 4 },
  tannat:         { acidity: 3, body: 5, tannin: 5, sweetness: 1, alcohol: 4, fruit: 4 },
  petiteSirah:    { acidity: 3, body: 5, tannin: 5, sweetness: 1, alcohol: 4, fruit: 5 },
  carignan:       { acidity: 4, body: 3, tannin: 4, sweetness: 1, alcohol: 3, fruit: 3 },
  cinsault:       { acidity: 4, body: 2, tannin: 2, sweetness: 1, alcohol: 2, fruit: 4 },
  blaufrankisch:  { acidity: 4, body: 3, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 },
  zweigelt:       { acidity: 4, body: 3, tannin: 2, sweetness: 1, alcohol: 3, fruit: 4 },
  xinomavro:      { acidity: 5, body: 3, tannin: 5, sweetness: 1, alcohol: 3, fruit: 3 },
  agiorgitiko:    { acidity: 3, body: 4, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 },
  saperavi:       { acidity: 3, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 4 },
  petitVerdot:    { acidity: 3, body: 5, tannin: 5, sweetness: 1, alcohol: 4, fruit: 4 },
  corvina:        { acidity: 4, body: 4, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 }, # Amarone / Valpolicella base
  menica:         { acidity: 4, body: 3, tannin: 3, sweetness: 1, alcohol: 3, fruit: 4 }, # Mencía

  # --- New white varieties ---
  pinotBlanc:     { acidity: 3, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  vermentino:     { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  fiano:          { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  greco:          { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  arneis:         { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  cortese:        { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 2 }, # Gavi
  trebbiano:      { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 2 },
  furmint:        { acidity: 5, body: 3, tannin: 1, sweetness: 2, alcohol: 3, fruit: 3 }, # Tokaji dry / sweet base
  assyrtiko:      { acidity: 5, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  godello:        { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  loureiro:       { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 4 }, # Vinho Verde component
  silvaner:       { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 2 },
  mullerThurgau:  { acidity: 3, body: 2, tannin: 1, sweetness: 2, alcohol: 2, fruit: 3 },
  muscat:         { acidity: 4, body: 2, tannin: 1, sweetness: 2, alcohol: 2, fruit: 5 }, # dry/aromatic Muscat
  rkatsiteli:     { acidity: 4, body: 3, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  marsanne:       { acidity: 3, body: 4, tannin: 1, sweetness: 1, alcohol: 3, fruit: 3 },
  roussanne:      { acidity: 3, body: 4, tannin: 1, sweetness: 1, alcohol: 3, fruit: 4 },
  macabeo:        { acidity: 3, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },

  # --- New sparkling / specialty styles ---
  cremant:        { acidity: 4, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  sekt:           { acidity: 5, body: 2, tannin: 1, sweetness: 1, alcohol: 2, fruit: 3 },
  lambrusco:      { acidity: 4, body: 2, tannin: 2, sweetness: 2, alcohol: 2, fruit: 4 },
  orangeWine:     { acidity: 4, body: 3, tannin: 3, sweetness: 1, alcohol: 3, fruit: 3 }, # skin-contact white style

  # --- New dessert / fortified ---
  icewine:        { acidity: 5, body: 3, tannin: 1, sweetness: 5, alcohol: 2, fruit: 5 },
  tokaji:         { acidity: 5, body: 4, tannin: 1, sweetness: 5, alcohol: 3, fruit: 4 },
  madeira:        { acidity: 4, body: 4, tannin: 1, sweetness: 3, alcohol: 5, fruit: 3 },
  vinSanto:       { acidity: 3, body: 4, tannin: 1, sweetness: 5, alcohol: 4, fruit: 4 },
}

# ---------------------------------------------------------------------------
# Wine profile definitions
# ---------------------------------------------------------------------------
wine_profiles_data = [
  # ========== EXISTING PROFILES (from db/seeds.rb) ==========
  { slug: "pinot-noir", name: "Pinot Noir", color: "Red",
    grapes: ["Pinot Noir"], regions: ["Burgundy", "Oregon", "New Zealand"],
    notes: ["cherry", "raspberry", "earth", "violet"],
    serving: "Great with roast chicken, mushrooms, salmon, and charcuterie.",
    params_key: :pinotNoir },

  { slug: "cabernet-sauvignon", name: "Cabernet Sauvignon", color: "Red",
    grapes: ["Cabernet Sauvignon"], regions: ["Bordeaux", "Napa Valley", "Coonawarra"],
    notes: ["blackcurrant", "cedar", "graphite", "mint"],
    serving: "Built for steak, lamb, hard cheeses, and richer sauces.",
    params_key: :cab },

  { slug: "merlot", name: "Merlot", color: "Red",
    grapes: ["Merlot"], regions: ["Right Bank Bordeaux", "Washington State", "Chile"],
    notes: ["plum", "black cherry", "cocoa", "bay leaf"],
    serving: "Easy with burgers, roast pork, tomato pasta, and soft cheeses.",
    params_key: :merlot },

  { slug: "syrah-shiraz", name: "Syrah / Shiraz", color: "Red",
    grapes: ["Syrah", "Shiraz"], regions: ["Northern Rhone", "Barossa Valley", "McLaren Vale"],
    notes: ["blackberry", "pepper", "smoke", "olive"],
    serving: "Strong match for barbecue, grilled vegetables, lamb, and spices.",
    params_key: :syrah },

  { slug: "sangiovese", name: "Sangiovese", color: "Red",
    grapes: ["Sangiovese"], regions: ["Chianti", "Brunello di Montalcino", "Tuscany"],
    notes: ["red cherry", "tomato leaf", "dried herbs", "leather"],
    serving: "A natural partner for pizza, pasta, ragu, and grilled meats.",
    params_key: :sangiovese },

  { slug: "chardonnay", name: "Chardonnay", color: "White",
    grapes: ["Chardonnay"], regions: ["Burgundy", "California", "Margaret River"],
    notes: ["apple", "citrus", "butter", "vanilla"],
    serving: "Works with roast chicken, creamy sauces, seafood, and corn.",
    params_key: :chardonnay },

  { slug: "sauvignon-blanc", name: "Sauvignon Blanc", color: "White",
    grapes: ["Sauvignon Blanc"], regions: ["Marlborough", "Loire Valley", "Adelaide Hills"],
    notes: ["lime", "passionfruit", "grass", "gooseberry"],
    serving: "Bright with goat cheese, salads, prawns, herbs, and citrus.",
    params_key: :sauvBlanc },

  { slug: "riesling", name: "Riesling", color: "White",
    grapes: ["Riesling"], regions: ["Mosel", "Clare Valley", "Alsace"],
    notes: ["lime", "green apple", "jasmine", "petrol"],
    serving: "Excellent with spicy food, pork, seafood, and salty snacks.",
    params_key: :riesling },

  { slug: "prosecco", name: "Prosecco", color: "Sparkling",
    grapes: ["Glera"], regions: ["Veneto", "Friuli"],
    notes: ["pear", "apple blossom", "melon", "lemon"],
    serving: "Pour with brunch, fried snacks, fresh fruit, and aperitivo plates.",
    params_key: :prosecco },

  { slug: "rose", name: "Dry Rose", color: "Rose",
    grapes: ["Grenache", "Cinsault", "Syrah"], regions: ["Provence", "Bandol", "South Australia"],
    notes: ["strawberry", "watermelon", "citrus", "white flowers"],
    serving: "Flexible with seafood, picnic food, grilled chicken, and mezze.",
    params_key: :rose },

  { slug: "tempranillo", name: "Tempranillo", color: "Red",
    grapes: ["Tempranillo"], regions: ["Rioja", "Ribera del Duero", "Toro"],
    notes: ["red cherry", "dried fig", "tobacco", "leather"],
    serving: "Pairs with grilled lamb, chorizo, manchego, and beef stew.",
    params_key: :tempranillo },

  { slug: "malbec", name: "Malbec", color: "Red",
    grapes: ["Malbec"], regions: ["Mendoza", "Cahors", "Patagonia"],
    notes: ["plum", "blackberry", "violet", "cocoa"],
    serving: "Perfect with grilled steak, empanadas, barbecue, and blue cheese.",
    params_key: :malbec },

  { slug: "zinfandel", name: "Zinfandel", color: "Red",
    grapes: ["Zinfandel"], regions: ["Sonoma", "Napa Valley", "Paso Robles"],
    notes: ["brambleberry", "jammy fruit", "black pepper", "vanilla"],
    serving: "Great with pulled pork, ribs, smoky barbecue, and pizza.",
    params_key: :zinfandel },

  { slug: "nebbiolo", name: "Nebbiolo", color: "Red",
    grapes: ["Nebbiolo"], regions: ["Piedmont", "Barolo", "Barbaresco"],
    notes: ["tar", "rose", "dried cherry", "truffle"],
    serving: "Matches braised beef, risotto, aged hard cheese, and truffle dishes.",
    params_key: :nebbiolo },

  { slug: "gamay", name: "Gamay (Beaujolais)", color: "Red",
    grapes: ["Gamay"], regions: ["Beaujolais", "Loire Valley"],
    notes: ["red berry", "banana", "candy", "floral"],
    serving: "Lively with charcuterie, roasted chicken, soft cheeses, and salads.",
    params_key: :gamay },

  { slug: "pinot-grigio", name: "Pinot Grigio", color: "White",
    grapes: ["Pinot Grigio"], regions: ["Friuli", "Trentino", "Veneto"],
    notes: ["lemon zest", "green apple", "pear", "almond"],
    serving: "Clean with seafood pasta, oysters, light salads, and caprese.",
    params_key: :pinotGrigio },

  { slug: "pinot-gris", name: "Pinot Gris", color: "White",
    grapes: ["Pinot Gris"], regions: ["Alsace", "Oregon", "New Zealand"],
    notes: ["pear", "honey", "stone fruit", "spice"],
    serving: "Versatile with roast pork, asian cuisine, soft cheeses, and pumpkin.",
    params_key: :pinotGris },

  { slug: "viognier", name: "Viognier", color: "White",
    grapes: ["Viognier"], regions: ["Condrieu", "Margaret River", "Virginia"],
    notes: ["apricot", "peach", "honeysuckle", "ginger"],
    serving: "Lovely with lobster, scallops, spicy curries, and roast chicken.",
    params_key: :viognier },

  { slug: "gewurztraminer", name: "Gewurztraminer", color: "White",
    grapes: ["Gewurztraminer"], regions: ["Alsace", "Pfalz", "Marlborough"],
    notes: ["lychee", "rose petal", "turkish delight", "ginger"],
    serving: "Stunning with thai food, indian curries, smoked salmon, and strong cheese.",
    params_key: :gewurz },

  { slug: "chenin-blanc", name: "Chenin Blanc", color: "White",
    grapes: ["Chenin Blanc"], regions: ["Loire Valley", "Stellenbosch", "California"],
    notes: ["quince", "honeydew", "chamomile", "wet stone"],
    serving: "Bright with roast chicken, pork, goat cheese, and vegetable tarts.",
    params_key: :chenin },

  { slug: "semillon", name: "Semillon", color: "White",
    grapes: ["Semillon"], regions: ["Hunter Valley", "Bordeaux", "Margaret River"],
    notes: ["lemon curd", "beeswax", "lanolin", "toast"],
    serving: "Classic with roast chicken, seafood, and creamy pasta.",
    params_key: :semillon },

  { slug: "gruner-veltliner", name: "Gruner Veltliner", color: "White",
    grapes: ["Gruner Veltliner"], regions: ["Wachau", "Kamptal", "Kremstal"],
    notes: ["white pepper", "green pea", "lime", "lentil"],
    serving: "Beautifully matches schnitzel, asparagus, sushi, and fresh salads.",
    params_key: :gruner },

  { slug: "albarino", name: "Albarino", color: "White",
    grapes: ["Albarino"], regions: ["Rias Baixas", "Moncao", "Bairrada"],
    notes: ["saline", "citrus peel", "white peach", "jasmine"],
    serving: "Brilliant with grilled octopus, ceviche, sushi, and briny shellfish.",
    params_key: :albarino },

  { slug: "verdejo", name: "Verdejo", color: "White",
    grapes: ["Verdejo"], regions: ["Rueda", "La Mancha"],
    notes: ["fennel", "grapefruit", "broom flower", "cut grass"],
    serving: "Cuts through garlic prawns, paella, grilled vegetables, and tapas.",
    params_key: :verdejo },

  { slug: "champagne", name: "Champagne", color: "Sparkling",
    grapes: ["Chardonnay", "Pinot Noir", "Pinot Meunier"], regions: ["Champagne"],
    notes: ["brioche", "citrus", "green apple", "chalk"],
    serving: "Pour with oysters, caviar, fried chicken, and celebration toasts.",
    params_key: :champagne },

  { slug: "cava", name: "Cava", color: "Sparkling",
    grapes: ["Macabeo", "Parellada", "Xarel.lo"], regions: ["Penedes", "Catalonia"],
    notes: ["green apple", "almond", "toast", "lemon"],
    serving: "Lively with patatas bravas, jamon, seafood, and fried snacks.",
    params_key: :cava },

  { slug: "franciacorta", name: "Franciacorta", color: "Sparkling",
    grapes: ["Chardonnay", "Pinot Nero"], regions: ["Lombardy", "Franciacorta"],
    notes: ["almond paste", "white peach", "lemon curd", "biscuit"],
    serving: "Refined with cured meats, sushi, seafood risotto, and aperitivo.",
    params_key: :franciacorta },

  { slug: "moscato-d-asti", name: "Moscato d'Asti", color: "Dessert",
    grapes: ["Moscato Bianco"], regions: ["Asti", "Piedmont"],
    notes: ["orange blossom", "peach", "honey", "grape"],
    serving: "Luscious with panettone, fresh fruit, panna cotta, and pastries.",
    params_key: :moscato },

  { slug: "sauternes", name: "Sauternes", color: "Dessert",
    grapes: ["Semillon", "Sauvignon Blanc", "Muscadelle"], regions: ["Bordeaux", "Sauternes", "Barsac"],
    notes: ["apricot", "honey", "ginger", "beeswax"],
    serving: "Decadent with foie gras, blue cheese, tarte tatin, and creme brulee.",
    params_key: :sauternes },

  { slug: "port-tawny", name: "Tawny Port", color: "Dessert",
    grapes: ["Touriga Nacional", "Touriga Franca", "Tinta Roriz"], regions: ["Douro Valley"],
    notes: ["dried fig", "caramel", "walnut", "orange peel"],
    serving: "Wonderful with stilton, chocolate desserts, and toasted nuts.",
    params_key: :port },

  { slug: "sherry-oloroso", name: "Oloroso Sherry", color: "Dessert",
    grapes: ["Palomino"], regions: ["Jerez", "Andalusia"],
    notes: ["walnut", "toffee", "cinnamon", "dried orange"],
    serving: "Sip with aged manchego, olives, almonds, and rich stews.",
    params_key: :sherry },

  { slug: "pinotage", name: "Pinotage", color: "Red",
    grapes: ["Pinotage"], regions: ["Stellenbosch", "Franschhoek", "Swartland"],
    notes: ["smoked meat", "plum", "banana", "earthy spice"],
    serving: "Barbecue champion - pairs with boerewors, lamb chops, and grilled meats.",
    params_key: :pinotage },

  { slug: "torrontes", name: "Torrontes", color: "White",
    grapes: ["Torrontes"], regions: ["Salta", "Mendoza", "Cafayate"],
    notes: ["grapefruit", "rose", "lychee", "herbal lift"],
    serving: "Vivid with ceviche, grilled fish, empanadas, and spicy latin cuisine.",
    params_key: :torrontes },

  { slug: "sangiovese-blend-super-tuscan", name: "Super Tuscan Blend", color: "Red",
    grapes: ["Sangiovese", "Cabernet Sauvignon", "Merlot"], regions: ["Tuscany", "Bolgheri"],
    notes: ["dark cherry", "cedar", "leather", "tobacco"],
    serving: "Great with bistecca alla fiorentina, rich pasta, and aged pecorino.",
    params_key: :superTuscan },

  # ========== NEW RED VARIETIES ==========
  { slug: "grenache", name: "Grenache / Garnacha", color: "Red",
    grapes: ["Grenache", "Garnacha"], regions: ["Southern Rhone", "Priorat", "McLaren Vale"],
    notes: ["strawberry", "raspberry", "white pepper", "garrigue"],
    serving: "Ideal with roasted lamb, Provençal stews, grilled sausages, and ratatouille.",
    params_key: :grenache },

  { slug: "cabernet-franc", name: "Cabernet Franc", color: "Red",
    grapes: ["Cabernet Franc"], regions: ["Loire Valley", "Bordeaux", "Finger Lakes"],
    notes: ["red currant", "bell pepper", "graphite", "violet"],
    serving: "Excellent with roast duck, vegetable dishes, goat cheese, and lighter red meats.",
    params_key: :cabFranc },

  { slug: "carmenere", name: "Carmenere", color: "Red",
    grapes: ["Carmenere"], regions: ["Colchagua", "Maipo", "Cachapoal"],
    notes: ["green pepper", "dark berry", "coffee", "spice"],
    serving: "Pairs with grilled meats, empanadas, spicy stews, and aged cheeses.",
    params_key: :carmenere },

  { slug: "mourvedre", name: "Mourvedre / Monastrell", color: "Red",
    grapes: ["Mourvedre", "Monastrell"], regions: ["Bandol", "Jumilla", "Barossa"],
    notes: ["blackberry", "game", "lavender", "dark chocolate"],
    serving: "Matches game, slow-cooked stews, grilled meats, and strong cheeses.",
    params_key: :mourvedre },

  { slug: "barbera", name: "Barbera", color: "Red",
    grapes: ["Barbera"], regions: ["Piedmont", "Asti", "Alba"],
    notes: ["sour cherry", "plum", "anise", "violet"],
    serving: "Food-friendly with tomato pasta, pizza, salumi, and grilled vegetables.",
    params_key: :barbera },

  { slug: "dolcetto", name: "Dolcetto", color: "Red",
    grapes: ["Dolcetto"], regions: ["Piedmont", "Alba", "Dogliani"],
    notes: ["black cherry", "licorice", "almond", "bitter chocolate"],
    serving: "Everyday match for pasta, antipasti, roasted poultry, and soft cheeses.",
    params_key: :dolcetto },

  { slug: "montepulciano", name: "Montepulciano", color: "Red",
    grapes: ["Montepulciano"], regions: ["Abruzzo", "Marche"],
    notes: ["black cherry", "plum", "herbs", "earth"],
    serving: "Great with pasta in meat sauce, grilled sausages, and pizza.",
    params_key: :montepulciano },

  { slug: "aglianico", name: "Aglianico", color: "Red",
    grapes: ["Aglianico"], regions: ["Campania", "Basilicata", "Taurasi"],
    notes: ["dark cherry", "tobacco", "leather", "spice"],
    serving: "Built for braised meats, aged cheeses, and rich southern Italian dishes.",
    params_key: :aglianico },

  { slug: "nero-d-avola", name: "Nero d'Avola", color: "Red",
    grapes: ["Nero d'Avola"], regions: ["Sicily", "Noto", "Vittoria"],
    notes: ["black cherry", "plum", "licorice", "mediterranean herbs"],
    serving: "Pairs with grilled tuna, pasta alla norma, sausages, and spicy dishes.",
    params_key: :neroDAvola },

  { slug: "primitivo", name: "Primitivo", color: "Red",
    grapes: ["Primitivo"], regions: ["Puglia", "Manduria", "Gioia del Colle"],
    notes: ["ripe blackberry", "prune", "spice", "chocolate"],
    serving: "Bold with barbecue, aged pecorino, spicy salumi, and rich pasta.",
    params_key: :primitivo },

  { slug: "touriga-nacional", name: "Touriga Nacional", color: "Red",
    grapes: ["Touriga Nacional"], regions: ["Douro", "Dao", "Alentejo"],
    notes: ["blackberry", "violet", "licorice", "bergamot"],
    serving: "Excellent with grilled meats, game, and hard Portuguese cheeses.",
    params_key: :tourigaNacional },

  { slug: "tannat", name: "Tannat", color: "Red",
    grapes: ["Tannat"], regions: ["Madiran", "Uruguay", "Madiran"],
    notes: ["black fruit", "tobacco", "espresso", "firm structure"],
    serving: "Needs rich food: grilled steak, cassoulet, hard cheeses.",
    params_key: :tannat },

  { slug: "petite-sirah", name: "Petite Sirah", color: "Red",
    grapes: ["Petite Sirah"], regions: ["California", "Lodi", "Paso Robles"],
    notes: ["blueberry", "black pepper", "cocoa", "ink"],
    serving: "Powerful with barbecue, grilled meats, and strong cheeses.",
    params_key: :petiteSirah },

  { slug: "carignan", name: "Carignan / Carinena", color: "Red",
    grapes: ["Carignan"], regions: ["Priorat", "Languedoc", "Sardinia"],
    notes: ["red berry", "spice", "herbs", "earth"],
    serving: "Good with grilled meats, stews, and Mediterranean dishes.",
    params_key: :carignan },

  { slug: "cinsault", name: "Cinsault", color: "Red",
    grapes: ["Cinsault"], regions: ["Languedoc", "Rhone", "South Africa"],
    notes: ["red berry", "floral", "spice", "light earth"],
    serving: "Chillable with charcuterie, salads, and light grilled foods.",
    params_key: :cinsault },

  { slug: "blaufrankisch", name: "Blaufrankisch", color: "Red",
    grapes: ["Blaufrankisch"], regions: ["Burgenland", "Hungary", "Austria"],
    notes: ["black cherry", "pepper", "herbs", "mineral"],
    serving: "Versatile with roasted meats, stews, and Central European cuisine.",
    params_key: :blaufrankisch },

  { slug: "zweigelt", name: "Zweigelt", color: "Red",
    grapes: ["Zweigelt"], regions: ["Austria", "Burgenland", "Niederosterreich"],
    notes: ["cherry", "berry", "pepper", "soft spice"],
    serving: "Easy with pasta, roast chicken, and mild cheeses.",
    params_key: :zweigelt },

  { slug: "xinomavro", name: "Xinomavro", color: "Red",
    grapes: ["Xinomavro"], regions: ["Naoussa", "Amyndeon", "Macedonia"],
    notes: ["tomato", "olive", "rose", "earth"],
    serving: "Pairs with grilled lamb, tomato-based dishes, and aged cheeses.",
    params_key: :xinomavro },

  { slug: "agiorgitiko", name: "Agiorgitiko", color: "Red",
    grapes: ["Agiorgitiko"], regions: ["Nemea", "Peloponnese"],
    notes: ["red berry", "spice", "soft tannin", "plum"],
    serving: "Friendly with grilled meats, mezze, and Mediterranean fare.",
    params_key: :agiorgitiko },

  { slug: "saperavi", name: "Saperavi", color: "Red",
    grapes: ["Saperavi"], regions: ["Georgia", "Kakheti"],
    notes: ["dark berry", "spice", "earth", "structure"],
    serving: "Matches Georgian cuisine, grilled meats, and strong cheeses.",
    params_key: :saperavi },

  { slug: "petit-verdot", name: "Petit Verdot", color: "Red",
    grapes: ["Petit Verdot"], regions: ["Bordeaux", "Napa", "Australia"],
    notes: ["violet", "black fruit", "spice", "firm tannin"],
    serving: "Often a blender; standalone styles suit rich red meats and hard cheese.",
    params_key: :petitVerdot },

  { slug: "corvina", name: "Corvina (Valpolicella / Amarone)", color: "Red",
    grapes: ["Corvina", "Rondinella", "Molinara"], regions: ["Valpolicella", "Veneto"],
    notes: ["cherry", "dried fruit", "almond", "spice"],
    serving: "Amarone with rich stews and aged cheese; lighter styles with pasta and antipasti.",
    params_key: :corvina },

  { slug: "mencia", name: "Mencia", color: "Red",
    grapes: ["Mencia"], regions: ["Bierzo", "Ribeira Sacra", "Valdeorras"],
    notes: ["red fruit", "herbs", "mineral", "floral"],
    serving: "Elegant with roasted meats, mushrooms, and Galician cuisine.",
    params_key: :menica },

  # ========== NEW WHITE VARIETIES ==========
  { slug: "pinot-blanc", name: "Pinot Blanc", color: "White",
    grapes: ["Pinot Blanc"], regions: ["Alsace", "Alto Adige", "Oregon"],
    notes: ["apple", "pear", "almond", "soft spice"],
    serving: "Gentle with roast chicken, mild cheeses, and light seafood.",
    params_key: :pinotBlanc },

  { slug: "vermentino", name: "Vermentino", color: "White",
    grapes: ["Vermentino"], regions: ["Sardinia", "Liguria", "Corsica"],
    notes: ["citrus", "herbs", "saline", "stone fruit"],
    serving: "Perfect with seafood, pesto, grilled fish, and Mediterranean salads.",
    params_key: :vermentino },

  { slug: "fiano", name: "Fiano", color: "White",
    grapes: ["Fiano"], regions: ["Campania", "Avellino", "Sicily"],
    notes: ["hazelnut", "honey", "citrus", "floral"],
    serving: "Excellent with seafood, white meats, and southern Italian dishes.",
    params_key: :fiano },

  { slug: "greco", name: "Greco", color: "White",
    grapes: ["Greco"], regions: ["Campania", "Greco di Tufo"],
    notes: ["peach", "almond", "mineral", "citrus"],
    serving: "Pairs with seafood, fried foods, and light pasta.",
    params_key: :greco },

  { slug: "arneis", name: "Arneis", color: "White",
    grapes: ["Arneis"], regions: ["Piedmont", "Roero"],
    notes: ["pear", "apricot", "almond", "herbs"],
    serving: "Lovely with antipasti, light pasta, and mild cheeses.",
    params_key: :arneis },

  { slug: "cortese", name: "Cortese (Gavi)", color: "White",
    grapes: ["Cortese"], regions: ["Gavi", "Piedmont"],
    notes: ["green apple", "citrus", "mineral", "almond"],
    serving: "Classic with seafood, pesto, and light antipasti.",
    params_key: :cortese },

  { slug: "trebbiano", name: "Trebbiano", color: "White",
    grapes: ["Trebbiano"], regions: ["Abruzzo", "Tuscany", "Umbria"],
    notes: ["citrus", "apple", "herbs", "light floral"],
    serving: "Everyday with seafood, light pasta, and salads.",
    params_key: :trebbiano },

  { slug: "furmint", name: "Furmint", color: "White",
    grapes: ["Furmint"], regions: ["Tokaj", "Somlo", "Hungary"],
    notes: ["apple", "honey", "smoke", "mineral"],
    serving: "Dry styles with seafood and poultry; sweet Tokaji with foie gras and blue cheese.",
    params_key: :furmint },

  { slug: "assyrtiko", name: "Assyrtiko", color: "White",
    grapes: ["Assyrtiko"], regions: ["Santorini", "Greece"],
    notes: ["citrus", "saline", "smoke", "stone"],
    serving: "Brilliant with grilled octopus, seafood, and Greek mezze.",
    params_key: :assyrtiko },

  { slug: "godello", name: "Godello", color: "White",
    grapes: ["Godello"], regions: ["Valdeorras", "Bierzo", "Ribeira Sacra"],
    notes: ["stone fruit", "citrus", "mineral", "herbs"],
    serving: "Great with seafood, white meats, and Galician cuisine.",
    params_key: :godello },

  { slug: "loureiro", name: "Loureiro (Vinho Verde)", color: "White",
    grapes: ["Loureiro"], regions: ["Vinho Verde", "Minho"],
    notes: ["citrus", "floral", "peach", "crisp"],
    serving: "Refreshing with seafood, salads, and light summer dishes.",
    params_key: :loureiro },

  { slug: "silvaner", name: "Silvaner", color: "White",
    grapes: ["Silvaner"], regions: ["Franken", "Rheinhessen", "Alsace"],
    notes: ["apple", "herbs", "earth", "mineral"],
    serving: "Classic with asparagus, white asparagus, and light German fare.",
    params_key: :silvaner },

  { slug: "muller-thurgau", name: "Muller-Thurgau", color: "White",
    grapes: ["Muller-Thurgau"], regions: ["Germany", "Alto Adige", "New Zealand"],
    notes: ["floral", "apple", "muscat-like", "light"],
    serving: "Easy with light salads, mild cheeses, and casual meals.",
    params_key: :mullerThurgau },

  { slug: "muscat", name: "Muscat (dry / aromatic)", color: "White",
    grapes: ["Muscat"], regions: ["Alsace", "Piedmont", "Australia"],
    notes: ["grape", "orange blossom", "rose", "citrus"],
    serving: "Aromatic with spicy Asian food, fruit, and mild cheeses.",
    params_key: :muscat },

  { slug: "rkatsiteli", name: "Rkatsiteli", color: "White",
    grapes: ["Rkatsiteli"], regions: ["Georgia", "Kakheti"],
    notes: ["apple", "quince", "herbs", "walnut"],
    serving: "Traditional with Georgian dishes; also with poultry and mild cheeses.",
    params_key: :rkatsiteli },

  { slug: "marsanne", name: "Marsanne", color: "White",
    grapes: ["Marsanne"], regions: ["Northern Rhone", "Australia", "California"],
    notes: ["almond", "honey", "stone fruit", "wax"],
    serving: "Pairs with rich fish, poultry, and creamy sauces.",
    params_key: :marsanne },

  { slug: "roussanne", name: "Roussanne", color: "White",
    grapes: ["Roussanne"], regions: ["Northern Rhone", "California", "Australia"],
    notes: ["pear", "herbal tea", "honey", "floral"],
    serving: "Excellent with roasted poultry, seafood, and mild cheeses.",
    params_key: :roussanne },

  { slug: "macabeo", name: "Macabeo / Viura", color: "White",
    grapes: ["Macabeo", "Viura"], regions: ["Rioja", "Penedes", "Catalonia"],
    notes: ["apple", "fennel", "citrus", "floral"],
    serving: "Versatile with seafood, light tapas, and Spanish cuisine.",
    params_key: :macabeo },

  # ========== NEW SPARKLING / SPECIALTY ==========
  { slug: "cremant", name: "Cremant", color: "Sparkling",
    grapes: ["Chardonnay", "Pinot Noir", "Chenins", "local varieties"], regions: ["Alsace", "Burgundy", "Loire"],
    notes: ["apple", "citrus", "brioche", "fine mousse"],
    serving: "Aperitif or with seafood, fried foods, and celebrations.",
    params_key: :cremant },

  { slug: "sekt", name: "Sekt", color: "Sparkling",
    grapes: ["Riesling", "Pinot varieties"], regions: ["Germany", "Austria"],
    notes: ["apple", "citrus", "floral", "crisp"],
    serving: "Refreshing aperitif; pairs with light canapes and seafood.",
    params_key: :sekt },

  { slug: "lambrusco", name: "Lambrusco", color: "Sparkling",
    grapes: ["Lambrusco"], regions: ["Emilia-Romagna", "Modena", "Reggio"],
    notes: ["red berry", "foam", "slight sweetness", "fresh"],
    serving: "Classic with pizza, cured meats, and Emilia-Romagna fare.",
    params_key: :lambrusco },

  { slug: "orange-wine", name: "Orange Wine (skin-contact)", color: "Orange",
    grapes: ["various white varieties"], regions: ["Georgia", "Friuli", "Slovenia"],
    notes: ["tea", "dried apricot", "tannin", "oxidative notes"],
    serving: "Pairs with spiced foods, hard cheeses, and charcuterie.",
    params_key: :orangeWine },

  # ========== NEW DESSERT / FORTIFIED ==========
  { slug: "icewine", name: "Icewine / Eiswein", color: "Dessert",
    grapes: ["Riesling", "Vidal", "Cabernet Franc"], regions: ["Canada", "Germany", "Austria"],
    notes: ["tropical fruit", "honey", "high acidity", "concentrated"],
    serving: "Sip with blue cheese, fruit tarts, and pure desserts.",
    params_key: :icewine },

  { slug: "tokaji", name: "Tokaji Aszu", color: "Dessert",
    grapes: ["Furmint", "Harslevelu", "Muscat"], regions: ["Tokaj", "Hungary"],
    notes: ["apricot", "honey", "orange peel", "botrytis"],
    serving: "Legendary with foie gras, blue cheese, and fruit desserts.",
    params_key: :tokaji },

  { slug: "madeira", name: "Madeira", color: "Dessert",
    grapes: ["Sercial", "Verdelho", "Bual", "Malmsey"], regions: ["Madeira"],
    notes: ["caramel", "nuts", "citrus peel", "oxidative"],
    serving: "From dry aperitif to sweet with nuts, chocolate, and cheese.",
    params_key: :madeira },

  { slug: "vin-santo", name: "Vin Santo", color: "Dessert",
    grapes: ["Trebbiano", "Malvasia"], regions: ["Tuscany"],
    notes: ["dried fruit", "honey", "nut", "caramel"],
    serving: "Traditional with cantucci biscuits and aged pecorino.",
    params_key: :vinSanto },
]

# ---------------------------------------------------------------------------
# Create WineProfile records
# ---------------------------------------------------------------------------
wine_profiles = WineProfile.create!(
  wine_profiles_data.map do |wp|
    {
      slug:    wp[:slug],
      name:    wp[:name],
      color:   wp[:color],
      grapes:  wp[:grapes].to_json,
      regions: wp[:regions].to_json,
      notes:   wp[:notes].to_json,
      serving: wp[:serving]
    }
  end
)

# ---------------------------------------------------------------------------
# Create WineProfileTasteParameter rows
# ---------------------------------------------------------------------------
wine_profiles.each do |wine_profile|
  line = wine_profiles_data.find { |item| item[:slug] == wine_profile.slug }
  next unless line && p[line[:params_key]]

  p[line[:params_key]].each do |param_slug, score|
    taste_parameter = TasteParameter.find_by(slug: param_slug.to_s)
    next unless taste_parameter

    WineProfileTasteParameter.create!(
      wine_profile:    wine_profile,
      taste_parameter: taste_parameter,
      score:           score
    )
  end
end

puts "wine_profiles_seed_claude.rb finished successfully!"
puts "  - #{TasteParameter.count} taste parameters"
puts "  - #{WineProfile.count} wine profiles"
puts "  - #{WineProfileTasteParameter.count} profile taste parameters"
puts ""
puts "Profiles by color:"
WineProfile.group(:color).count.each { |color, n| puts "  #{color}: #{n}" }
