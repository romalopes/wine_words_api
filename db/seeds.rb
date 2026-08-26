# db/seeds.rb
# Seed data for wine_prediction API

# --- Roles (instance rows in the DB: name + id) ---
Role.find_or_create_by!(name: "Super User")
Role.find_or_create_by!(name: "Reviewer")
Role.find_or_create_by!(name: "Reader")
Role.find_or_create_by!(name: "Guest")

Wine.destroy_all
WineProfile.destroy_all
TasteParameter.destroy_all
WineProfileTasteParameter.destroy_all
WineTasteParameter.destroy_all
Vintage.destroy_all

ActiveRecord::Base.connection.reset_pk_sequence!("wines")
ActiveRecord::Base.connection.reset_pk_sequence!("wine_profiles")
ActiveRecord::Base.connection.reset_pk_sequence!("taste_parameters")
ActiveRecord::Base.connection.reset_pk_sequence!("wine_profile_taste_parameters")
ActiveRecord::Base.connection.reset_pk_sequence!("wine_taste_parameters")
ActiveRecord::Base.connection.reset_pk_sequence!("vintages")

# Create taste parameters
taste_params_data = [
  { slug: 'acidity', label: 'Acidity', low: 'Soft', high: 'Sharp', help: 'How bright, fresh, or mouth-watering the wine feels.' },
  { slug: 'body', label: 'Body', low: 'Light', high: 'Full', help: 'The weight and richness of the wine on your palate.' },
  { slug: 'tannin', label: 'Tannin', low: 'Silky', high: 'Grippy', help: 'The drying texture, common in red wines.' },
  { slug: 'sweetness', label: 'Sweetness', low: 'Dry', high: 'Sweet', help: 'How much sugar or ripe sweetness you perceive.' },
  { slug: 'alcohol', label: 'Alcohol warmth', low: 'Cool', high: 'Warm', help: 'The heat or weight from alcohol.' },
  { slug: 'fruit', label: 'Fruit intensity', low: 'Subtle', high: 'Expressive', help: 'How strongly fruit aromas and flavors stand out.' }
]

TasteParameter.create(taste_params_data.map { |tp| {
  slug: tp[:slug],
  label: tp[:label],
  low: tp[:low],
  high: tp[:high],
  help: tp[:help]
} })

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
  viognier: { acidity: 3, body: 4, tannin: 1, sweetness: 2, alcohol: 4, fruit: 5 },
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
  superTuscan: { acidity: 4, body: 5, tannin: 4, sweetness: 1, alcohol: 4, fruit: 4 },
}

# Packaging details per wine slug
wine_details = {
  "pinot-noir" => { closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750 },
  "cabernet-sauvignon" => { closure: "Cork", alcohol_percentage: 14.5, volume_ml: 750 },
  "merlot" => { closure: "Cork", alcohol_percentage: 14.0, volume_ml: 750 },
  "syrah-shiraz" => { closure: "Screw cap", alcohol_percentage: 14.5, volume_ml: 750 },
  "sangiovese" => { closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750 },
  "chardonnay" => { closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750 },
  "sauvignon-blanc" => { closure: "Screw cap", alcohol_percentage: 12.5, volume_ml: 750 },
  "riesling" => { closure: "Screw cap", alcohol_percentage: 12.0, volume_ml: 750 },
  "prosecco" => { closure: "Cork", alcohol_percentage: 11.5, volume_ml: 750 },
  "rose" => { closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 },
  "tempranillo" => { closure: "Cork", alcohol_percentage: 14.0, volume_ml: 750 },
  "malbec" => { closure: "Cork", alcohol_percentage: 14.0, volume_ml: 750 },
  "zinfandel" => { closure: "Cork", alcohol_percentage: 14.5, volume_ml: 750 },
  "nebbiolo" => { closure: "Cork", alcohol_percentage: 14.0, volume_ml: 750 },
  "gamay" => { closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 },
  "pinot-grigio" => { closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 },
  "pinot-gris" => { closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750 },
  "viognier" => { closure: "Screw cap", alcohol_percentage: 13.5, volume_ml: 750 },
  "gewurztraminer" => { closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750 },
  "chenin-blanc" => { closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 },
  "semillon" => { closure: "Screw cap", alcohol_percentage: 11.5, volume_ml: 750 },
  "gruner-veltliner" => { closure: "Screw cap", alcohol_percentage: 12.5, volume_ml: 750 },
  "albarino" => { closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 },
  "verdejo" => { closure: "Cork", alcohol_percentage: 13.0, volume_ml: 750 },
  "champagne" => { closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 },
  "cava" => { closure: "Cork", alcohol_percentage: 11.5, volume_ml: 750 },
  "franciacorta" => { closure: "Cork", alcohol_percentage: 12.5, volume_ml: 750 },
  "moscato-d-asti" => { closure: "Cork", alcohol_percentage: 5.5, volume_ml: 750 },
  "sauternes" => { closure: "Cork", alcohol_percentage: 14.0, volume_ml: 375 },
  "port-tawny" => { closure: "Cork", alcohol_percentage: 19.5, volume_ml: 750 },
  "sherry-oloroso" => { closure: "Cork", alcohol_percentage: 18.0, volume_ml: 750 },
  "pinotage" => { closure: "Screw cap", alcohol_percentage: 14.0, volume_ml: 750 },
  "torrontes" => { closure: "Cork", alcohol_percentage: 13.0, volume_ml: 750 },
  "sangiovese-blend-super-tuscan" => { closure: "Cork", alcohol_percentage: 14.5, volume_ml: 750 },
  "penfolds-bin-389" => { closure: "Screw cap", alcohol_percentage: 14.5, volume_ml: 750 },
  "henschke-hill-of-grace" => { closure: "Cork", alcohol_percentage: 14.5, volume_ml: 750 },
  "leeuwin-estate-art-series" => { closure: "Screw cap", alcohol_percentage: 13.5, volume_ml: 750 },
  "grosset-polish-hill" => { closure: "Screw cap", alcohol_percentage: 12.5, volume_ml: 750 },
  "tyrrells-vat-1-semillon" => { closure: "Screw cap", alcohol_percentage: 10.5, volume_ml: 750 },
  "giaconda-chardonnay" => { closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750 },
  "yalumba-signature" => { closure: "Screw cap", alcohol_percentage: 14.5, volume_ml: 750 },
  "tolpuddle-pinot-noir" => { closure: "Cork", alcohol_percentage: 13.0, volume_ml: 750 },
  "de-bortoli-noble-one" => { closure: "Screw cap", alcohol_percentage: 10.5, volume_ml: 375 },
  "rockford-basket-press" => { closure: "Cork", alcohol_percentage: 14.5, volume_ml: 750 },
}

# Vintage data for wine profiles
vintage_library = {
  "pinot-noir" => [
    { year: 2018, prompt: "Cool, savoury vintage. Red cherry, forest floor, and a long, mineral finish." },
    { year: 2020, prompt: "Vibrant and perfumed. Bright raspberry, rose petal, and lifted acidity." },
    { year: 2022, prompt: "Generous, sun-kissed year. Plump red fruit, fine tannin, and a velvety mid-palate." },
  ],
  "cabernet-sauvignon" => [
    { year: 2018, prompt: "Classic, structured vintage. Cassis, cedar, graphite, and firm, age-worthy tannin." },
    { year: 2020, prompt: "Elegant and cool. Blackcurrant, mint, and a slate-driven finish." },
    { year: 2021, prompt: "Powerful and concentrated. Black fruit, cocoa, and a long, warming finish." },
  ],
  "merlot" => [
    { year: 2019, prompt: "Plush and approachable. Plum, chocolate, and a soft, rounded tannin." },
    { year: 2021, prompt: "Bright and fresh. Red cherry, herbs, and a medium-bodied, food-friendly frame." },
  ],
  "syrah-shiraz" => [
    { year: 2018, prompt: "Cool-climate elegance. White pepper, violet, and finely wrought tannin." },
    { year: 2020, prompt: "Warm and generous. Blackberry jam, clove, and warm, baking-spice finish." },
    { year: 2022, prompt: "Bold Barossa style. Dark fruit, chocolate, licorice, and plush alcohol." },
  ],
  "sangiovese" => [
    { year: 2019, prompt: "Classic Chianti year. Sour cherry, dried herbs, and a tangy acidity." },
    { year: 2021, prompt: "Riper, more generous. Red plum, leather, and a savoury finish." },
  ],
  "chardonnay" => [
    { year: 2019, prompt: "Linear and mineral. Lemon pith, oyster shell, and a long, saline finish." },
    { year: 2021, prompt: "Generous and creamy. Stone fruit, hazelnut, and gentle French oak." },
  ],
  "sauvignon-blanc" => [
    { year: 2020, prompt: "Classic Marlborough. Lime, passionfruit, and a crisp finish." },
    { year: 2022, prompt: "Softer, riper style. Stone fruit, citrus, and a rounder palate." },
  ],
  "riesling" => [
    { year: 2018, prompt: "Off-dry Mosel classic. Lime, green apple, slate, and a long, filigree finish." },
    { year: 2021, prompt: "Bone-dry Clare Valley. Lemon, bath salt, and a steely, dry finish." },
  ],
  "prosecco" => [
    { year: 2021, prompt: "Fresh and zippy. Pear, green apple, and lively, frothy bubbles." },
    { year: 2022, prompt: "Softer and riper. White peach, honeysuckle, and a creamy, easy-drinking mousse." },
  ],
  "rose" => [
    { year: 2021, prompt: "Pale, dry Provence style. Strawberry, melon, and a crisp, saline finish." },
    { year: 2023, prompt: "Bright, juicy, and aromatic. Red berries, citrus zest, and a clean finish." },
  ],
  "tempranillo" => [
    { year: 2018, prompt: "Traditional Rioja. Red cherry, dill, American oak, and silky tannin." },
    { year: 2020, prompt: "Riper, more modern. Black cherry, vanilla, and a richer, fuller body." },
  ],
  "malbec" => [
    { year: 2019, prompt: "Concentrated Mendoza vintage. Plum, violet, cocoa, and rich, velvety tannin." },
    { year: 2021, prompt: "Cooler, more elegant. Red fruit, herbs, and a fresh, structured finish." },
  ],
  "zinfandel" => [
    { year: 2018, prompt: "Ripe, heady vintage. Brambleberry, black pepper, vanilla, and warm alcohol." },
    { year: 2020, prompt: "Bright and balanced. Red fruit, spice, and a more elegant frame." },
  ],
  "nebbiolo" => [
    { year: 2017, prompt: "Classic Barolo. Tar, rose, dried cherry, and a long firm finish." },
    { year: 2019, prompt: "Softer, more approachable vintage. Red berries, herbs, and refined tannin." },
  ],
  "gamay" => [
    { year: 2021, prompt: "Bright, juicy Cru Beaujolais. Red berries, granite minerality, and low tannin." },
    { year: 2022, prompt: "Easy, bouncy and chillable. Cherry, banana, and a soft, juicy finish." },
  ],
  "pinot-grigio" => [
    { year: 2021, prompt: "Crisp Alto Adige style. Pear, almond, and a clean, mineral finish." },
    { year: 2022, prompt: "Softer, riper style. Lemon, melon, and a rounder finish." },
  ],
  "pinot-gris" => [
    { year: 2019, prompt: "Rich, Alsace style. Pear, honey, ginger, and a touch of sweetness." },
    { year: 2021, prompt: "Dry, mineral Oregon gris. Stone fruit, white flowers, and a clean finish." },
  ],
  "viognier" => [
    { year: 2020, prompt: "Aromatic Condrieu-style. Apricot, honeysuckle, and an oily mid-palate." },
    { year: 2022, prompt: "Modern, fresher viognier. Peach, ginger, and a brighter finish." },
  ],
  "gewurztraminer" => [
    { year: 2019, prompt: "Headily aromatic Alsace. Lychee, rose petal, Turkish delight." },
    { year: 2021, prompt: "Bone-dry style. Grapefruit pith, spice, and a long finish." },
  ],
  "chenin-blanc" => [
    { year: 2018, prompt: "Dry Vouvray. Quince, chamomile, wet stone, and a long finish." },
    { year: 2020, prompt: "Off-dry, honeyed. Pear, beeswax, and bright balancing acidity." },
  ],
  "semillon" => [
    { year: 2018, prompt: "Young Hunter Valley. Lemon, snow pea, and a tight racy finish." },
    { year: 2014, prompt: "Aged release. Toast, honey, lanolin, and a toasty complex palate." },
  ],
  "gruner-veltliner" => [
    { year: 2021, prompt: "Classic Wachau. White pepper, lentil, lime, and a crisp finish." },
    { year: 2022, prompt: "Riper Smaragd level. Stone fruit, spice, and a more textured palate." },
  ],
  "albarino" => [
    { year: 2021, prompt: "Atlantic-influenced Rias Baixas. Saline, citrus, and a stony finish." },
    { year: 2022, prompt: "Riper, rounder vintage. White peach, apricot, and a richer mid-palate." },
  ],
  "verdejo" => [
    { year: 2021, prompt: "Rueda classic. Fennel, grapefruit, and a crisp herbaceous finish." },
    { year: 2022, prompt: "Modern, more fruit-forward. Melon, stone fruit, and a softer finish." },
  ],
  "champagne" => [
    { year: 2014, prompt: "Vintage Champagne. Brioche, citrus, and a long mineral finish." },
    { year: 2018, prompt: "Generous, ripe vintage. Yellow apple, honey, and creamy bubbles." },
  ],
  "cava" => [
    { year: 2020, prompt: "Brut Nature Cava. Green apple, almond, and a dry mouth-watering finish." },
    { year: 2021, prompt: "Softer Brut. Pear, lemon, and an easy bready mid-palate." },
  ],
  "franciacorta" => [
    { year: 2018, prompt: "Satèn style. Almond, white peach, and a creamy persistent mousse." },
    { year: 2019, prompt: "Nature dosage. Lemon curd, bread crust, and a long mineral finish." },
  ],
  "moscato-d-asti" => [
    { year: 2021, prompt: "Fresh, fragrant Moscato. Orange blossom, peach, and a gentle frothy sweetness." },
    { year: 2022, prompt: "Riper, lusher vintage. Honey, grape, and a more generous sweetness." },
  ],
  "sauternes" => [
    { year: 2015, prompt: "Rich botrytis year. Apricot, honey, ginger, and bright acidity." },
    { year: 2017, prompt: "Concentrated and opulent. Mango, saffron, and a long sweet finish." },
  ],
  "port-tawny" => [
    { year: 2010, prompt: "10 year old Tawny. Dried fig, walnut, orange peel, and a long polished finish." },
    { year: 2015, prompt: "Fresher, fruitier Tawny. Plum, cherry, spice, and a more vibrant finish." },
  ],
  "sherry-oloroso" => [
    { year: 2010, prompt: "Dry, mature Oloroso. Walnut, toffee, leather, and a long savoury finish." },
    { year: 2015, prompt: "Younger, fresher Oloroso. Dried orange, spice, and a lifted rounder mouthfeel." },
  ],
  "pinotage" => [
    { year: 2019, prompt: "Modern, elegant style. Red berries, chocolate, and a smooth smoky finish." },
    { year: 2021, prompt: "Classic bold Pinotage. Smoked meat, plum, banana, and a robust tannin." },
  ],
  "torrontes" => [
    { year: 2021, prompt: "High-altitude Salta. Grapefruit, rose, lychee, and a long herbaceous finish." },
    { year: 2022, prompt: "Softer, riper vintage. Peach, white flowers, and a rounder palate." },
  ],
  "sangiovese-blend-super-tuscan" => [
    { year: 2018, prompt: "Iconic vintage. Dark cherry, cedar, leather, and a long powerful finish." },
    { year: 2020, prompt: "More elegant, structured. Red fruit, tobacco, and a fine-boned savoury frame." },
  ],
}

# Vintage data for wine test cases
vintage_test_library = {
  "penfolds-bin-389" => [
    { year: 2018, prompt: "A powerhouse Bin 389. Dark fruit, firm tannin, and a long oak-driven finish." },
    { year: 2020, prompt: "A more elegant, structured 389. Cassis, spice, and savoury fine-grained tannin." },
  ],
  "henschke-hill-of-grace" => [
    { year: 2017, prompt: "A cool, poised vintage. Black fruit, spice, and a long mineral age-worthy finish." },
    { year: 2019, prompt: "A riper, more opulent year. Plum, dark chocolate, and warm polished oak." },
  ],
  "leeuwin-estate-art-series" => [
    { year: 2019, prompt: "A bright, linear Art Series. Citrus, white peach, and a crystalline long finish." },
    { year: 2021, prompt: "A richer, more generous release. Stone fruit, hazelnut, and creamy integrated oak." },
  ],
  "grosset-polish-hill" => [
    { year: 2021, prompt: "Bone-dry, intense Polish Hill. Lime, bath salt, and a long focused finish." },
    { year: 2023, prompt: "A more approachable, juicy vintage. Lemon, white flowers, and a bright clean finish." },
  ],
  "tyrrells-vat-1-semillon" => [
    { year: 2018, prompt: "Young, racy Vat 1. Lemon, snow pea, and a tight bone-dry finish." },
    { year: 2010, prompt: "Aged release. Toast, honey, lanolin, and a complex toasty mid-palate." },
  ],
  "giaconda-chardonnay" => [
    { year: 2019, prompt: "Intense, mineral Giaconda. Citrus, struck match, and a long layered finish." },
    { year: 2021, prompt: "Riper, more generous. White peach, hazelnut, and a creamy oak-driven finish." },
  ],
  "yalumba-signature" => [
    { year: 2017, prompt: "Concentrated, structured vintage. Cassis, plum, and firm savoury tannin." },
    { year: 2019, prompt: "A more approachable release. Red fruit, spice, and a soft generous finish." },
  ],
  "tolpuddle-pinot-noir" => [
    { year: 2021, prompt: "Cool, fragrant vintage. Red cherry, rose, and a long fine mineral finish." },
    { year: 2022, prompt: "Riper, more plush. Plum, baking spice, and a soft generous mid-palate." },
  ],
  "de-bortoli-noble-one" => [
    { year: 2018, prompt: "Rich botrytis year. Apricot, honey, and a long luscious sweet finish." },
    { year: 2020, prompt: "A more focused, balanced vintage. Marmalade, ginger, and bright acidity." },
  ],
  "rockford-basket-press" => [
    { year: 2018, prompt: "Classic old-vine Barossa. Blackberry, dark chocolate, and warm generous alcohol." },
    { year: 2020, prompt: "A cooler, more elegant Basket Press. Red fruit, spice, and fine savoury tannin." },
  ],
}

# Create wine profiles
wine_profiles_data = [
  { slug: "pinot-noir", name: "Pinot Noir", color: "Red", grapes: ["Pinot Noir"], regions: ["Burgundy", "Oregon", "New Zealand"], notes: ["cherry", "raspberry", "earth", "violet"], serving: "Great with roast chicken, mushrooms, salmon, and charcuterie.", params_key: :pinotNoir },
  { slug: "cabernet-sauvignon", name: "Cabernet Sauvignon", color: "Red", grapes: ["Cabernet Sauvignon"], regions: ["Bordeaux", "Napa Valley", "Coonawarra"], notes: ["blackcurrant", "cedar", "graphite", "mint"], serving: "Built for steak, lamb, hard cheeses, and richer sauces.", params_key: :cab },
  { slug: "merlot", name: "Merlot", color: "Red", grapes: ["Merlot"], regions: ["Right Bank Bordeaux", "Washington State", "Chile"], notes: ["plum", "black cherry", "cocoa", "bay leaf"], serving: "Easy with burgers, roast pork, tomato pasta, and soft cheeses.", params_key: :merlot },
  { slug: "syrah-shiraz", name: "Syrah / Shiraz", color: "Red", grapes: ["Syrah", "Shiraz"], regions: ["Northern Rhone", "Barossa Valley", "McLaren Vale"], notes: ["blackberry", "pepper", "smoke", "olive"], serving: "Strong match for barbecue, grilled vegetables, lamb, and spices.", params_key: :syrah },
  { slug: "sangiovese", name: "Sangiovese", color: "Red", grapes: ["Sangiovese"], regions: ["Chianti", "Brunello di Montalcino", "Tuscany"], notes: ["red cherry", "tomato leaf", "dried herbs", "leather"], serving: "A natural partner for pizza, pasta, ragu, and grilled meats.", params_key: :sangiovese },
  { slug: "chardonnay", name: "Chardonnay", color: "White", grapes: ["Chardonnay"], regions: ["Burgundy", "California", "Margaret River"], notes: ["apple", "citrus", "butter", "vanilla"], serving: "Works with roast chicken, creamy sauces, seafood, and corn.", params_key: :chardonnay },
  { slug: "sauvignon-blanc", name: "Sauvignon Blanc", color: "White", grapes: ["Sauvignon Blanc"], regions: ["Marlborough", "Loire Valley", "Adelaide Hills"], notes: ["lime", "passionfruit", "grass", "gooseberry"], serving: "Bright with goat cheese, salads, prawns, herbs, and citrus.", params_key: :sauvBlanc },
  { slug: "riesling", name: "Riesling", color: "White", grapes: ["Riesling"], regions: ["Mosel", "Clare Valley", "Alsace"], notes: ["lime", "green apple", "jasmine", "petrol"], serving: "Excellent with spicy food, pork, seafood, and salty snacks.", params_key: :riesling },
  { slug: "prosecco", name: "Prosecco", color: "Sparkling", grapes: ["Glera"], regions: ["Veneto", "Friuli"], notes: ["pear", "apple blossom", "melon", "lemon"], serving: "Pour with brunch, fried snacks, fresh fruit, and aperitivo plates.", params_key: :prosecco },
  { slug: "rose", name: "Dry Rose", color: "Rose", grapes: ["Grenache", "Cinsault", "Syrah"], regions: ["Provence", "Bandol", "South Australia"], notes: ["strawberry", "watermelon", "citrus", "white flowers"], serving: "Flexible with seafood, picnic food, grilled chicken, and mezze.", params_key: :rose },
  { slug: "tempranillo", name: "Tempranillo", color: "Red", grapes: ["Tempranillo"], regions: ["Rioja", "Ribera del Duero", "Toro"], notes: ["red cherry", "dried fig", "tobacco", "leather"], serving: "Pairs with grilled lamb, chorizo, manchego, and beef stew.", params_key: :tempranillo },
  { slug: "malbec", name: "Malbec", color: "Red", grapes: ["Malbec"], regions: ["Mendoza", "Cahors", "Patagonia"], notes: ["plum", "blackberry", "violet", "cocoa"], serving: "Perfect with grilled steak, empanadas, barbecue, and blue cheese.", params_key: :malbec },
  { slug: "zinfandel", name: "Zinfandel", color: "Red", grapes: ["Zinfandel"], regions: ["Sonoma", "Napa Valley", "Paso Robles"], notes: ["brambleberry", "jammy fruit", "black pepper", "vanilla"], serving: "Great with pulled pork, ribs, smoky barbecue, and pizza.", params_key: :zinfandel },
  { slug: "nebbiolo", name: "Nebbiolo", color: "Red", grapes: ["Nebbiolo"], regions: ["Piedmont", "Barolo", "Barbaresco"], notes: ["tar", "rose", "dried cherry", "truffle"], serving: "Matches braised beef, risotto, aged hard cheese, and truffle dishes.", params_key: :nebbiolo },
  { slug: "gamay", name: "Gamay (Beaujolais)", color: "Red", grapes: ["Gamay"], regions: ["Beaujolais", "Loire Valley"], notes: ["red berry", "banana", "candy", "floral"], serving: "Lively with charcuterie, roasted chicken, soft cheeses, and salads.", params_key: :gamay },
  { slug: "pinot-grigio", name: "Pinot Grigio", color: "White", grapes: ["Pinot Grigio"], regions: ["Friuli", "Trentino", "Veneto"], notes: ["lemon zest", "green apple", "pear", "almond"], serving: "Clean with seafood pasta, oysters, light salads, and caprese.", params_key: :pinotGrigio },
  { slug: "pinot-gris", name: "Pinot Gris", color: "White", grapes: ["Pinot Gris"], regions: ["Alsace", "Oregon", "New Zealand"], notes: ["pear", "honey", "stone fruit", "spice"], serving: "Versatile with roast pork, asian cuisine, soft cheeses, and pumpkin.", params_key: :pinotGris },
  { slug: "viognier", name: "Viognier", color: "White", grapes: ["Viognier"], regions: ["Condrieu", "Margaret River", "Virginia"], notes: ["apricot", "peach", "honeysuckle", "ginger"], serving: "Lovely with lobster, scallops, spicy curries, and roast chicken.", params_key: :viognier },
  { slug: "gewurztraminer", name: "Gewurztraminer", color: "White", grapes: ["Gewurztraminer"], regions: ["Alsace", "Pfalz", "Marlborough"], notes: ["lychee", "rose petal", "turkish delight", "ginger"], serving: "Stunning with thai food, indian curries, smoked salmon, and strong cheese.", params_key: :gewurz },
  { slug: "chenin-blanc", name: "Chenin Blanc", color: "White", grapes: ["Chenin Blanc"], regions: ["Loire Valley", "Stellenbosch", "California"], notes: ["quince", "honeydew", "chamomile", "wet stone"], serving: "Bright with roast chicken, pork, goat cheese, and vegetable tarts.", params_key: :chenin },
  { slug: "semillon", name: "Semillon", color: "White", grapes: ["Semillon"], regions: ["Hunter Valley", "Bordeaux", "Margaret River"], notes: ["lemon curd", "beeswax", "lanolin", "toast"], serving: "Classic with roast chicken, seafood, and creamy pasta.", params_key: :semillon },
  { slug: "gruner-veltliner", name: "Gruner Veltliner", color: "White", grapes: ["Gruner Veltliner"], regions: ["Wachau", "Kamptal", "Kremstal"], notes: ["white pepper", "green pea", "lime", "lentil"], serving: "Beautifully matches schnitzel, asparagus, sushi, and fresh salads.", params_key: :gruner },
  { slug: "albarino", name: "Albarino", color: "White", grapes: ["Albarino"], regions: ["Rias Baixas", "Moncao", "Bairrada"], notes: ["saline", "citrus peel", "white peach", "jasmine"], serving: "Brilliant with grilled octopus, ceviche, sushi, and briny shellfish.", params_key: :albarino },
  { slug: "verdejo", name: "Verdejo", color: "White", grapes: ["Verdejo"], regions: ["Rueda", "La Mancha"], notes: ["fennel", "grapefruit", "broom flower", "cut grass"], serving: "Cuts through garlic prawns, paella, grilled vegetables, and tapas.", params_key: :verdejo },
  { slug: "champagne", name: "Champagne", color: "Sparkling", grapes: ["Chardonnay", "Pinot Noir", "Pinot Meunier"], regions: ["Champagne"], notes: ["brioche", "citrus", "green apple", "chalk"], serving: "Pour with oysters, caviar, fried chicken, and celebration toasts.", params_key: :champagne },
  { slug: "cava", name: "Cava", color: "Sparkling", grapes: ["Macabeo", "Parellada", "Xarel.lo"], regions: ["Penedes", "Catalonia"], notes: ["green apple", "almond", "toast", "lemon"], serving: "Lively with patatas bravas, jamon, seafood, and fried snacks.", params_key: :cava },
  { slug: "franciacorta", name: "Franciacorta", color: "Sparkling", grapes: ["Chardonnay", "Pinot Nero"], regions: ["Lombardy", "Franciacorta"], notes: ["almond paste", "white peach", "lemon curd", "biscuit"], serving: "Refined with cured meats, sushi, seafood risotto, and aperitivo.", params_key: :franciacorta },
  { slug: "moscato-d-asti", name: "Moscato d'Asti", color: "Dessert", grapes: ["Moscato Bianco"], regions: ["Asti", "Piedmont"], notes: ["orange blossom", "peach", "honey", "grape"], serving: "Luscious with panettone, fresh fruit, panna cotta, and pastries.", params_key: :moscato },
  { slug: "sauternes", name: "Sauternes", color: "Dessert", grapes: ["Semillon", "Sauvignon Blanc", "Muscadelle"], regions: ["Bordeaux", "Sauternes", "Barsac"], notes: ["apricot", "honey", "ginger", "beeswax"], serving: "Decadent with foie gras, blue cheese, tarte tatin, and creme brulee.", params_key: :sauternes },
  { slug: "port-tawny", name: "Tawny Port", color: "Dessert", grapes: ["Touriga Nacional", "Touriga Franca", "Tinta Roriz"], regions: ["Douro Valley"], notes: ["dried fig", "caramel", "walnut", "orange peel"], serving: "Wonderful with stilton, chocolate desserts, and toasted nuts.", params_key: :port },
  { slug: "sherry-oloroso", name: "Oloroso Sherry", color: "Dessert", grapes: ["Palomino"], regions: ["Jerez", "Andalusia"], notes: ["walnut", "toffee", "cinnamon", "dried orange"], serving: "Sip with aged manchego, olives, almonds, and rich stews.", params_key: :sherry },
  { slug: "pinotage", name: "Pinotage", color: "Red", grapes: ["Pinotage"], regions: ["Stellenbosch", "Franschhoek", "Swartland"], notes: ["smoked meat", "plum", "banana", "earthy spice"], serving: "Barbecue champion - pairs with boerewors, lamb chops, and grilled meats.", params_key: :pinotage },
  { slug: "torrontes", name: "Torrontes", color: "White", grapes: ["Torrontes"], regions: ["Salta", "Mendoza", "Cafayate"], notes: ["grapefruit", "rose", "lychee", "herbal lift"], serving: "Vivid with ceviche, grilled fish, empanadas, and spicy latin cuisine.", params_key: :torrontes },
  { slug: "sangiovese-blend-super-tuscan", name: "Super Tuscan Blend", color: "Red", grapes: ["Sangiovese", "Cabernet Sauvignon", "Merlot"], regions: ["Tuscany", "Bolgheri"], notes: ["dark cherry", "cedar", "leather", "tobacco"], serving: "Great with bistecca alla fiorentina, rich pasta, and aged pecorino.", params_key: :superTuscan },
]

wine_profiles = WineProfile.create(wine_profiles_data.map { |wp|
  details = wine_details[wp[:slug]] || {}
  {
    slug: wp[:slug],
    name: wp[:name],
    color: wp[:color],
    grapes: wp[:grapes].to_json,
    regions: wp[:regions].to_json,
    notes: wp[:notes].to_json,
    serving: wp[:serving]
  }
})

# Create wine profile taste parameters
wine_profiles.each do |wine_profile|
  line = wine_profiles_data.find { |item| item[:slug] == wine_profile.slug }
  p[line[:params_key]].each do |slug, score|
    taste_parameter = TasteParameter.find_by(slug: slug.to_s)
    WineProfileTasteParameter.create(
      wine_profile: wine_profile,
      taste_parameter: taste_parameter,
      score: score
    )
  end
end

# Create wine test cases with closure, alcohol, volume, and vintages
australian_wine_tests_data = [
  { slug: 'penfolds-bin-389', name: 'Penfolds Bin 389 Cabernet Shiraz', region: 'South Australia', color: 'Red', prompt: 'Classic Australian cabernet shiraz: dark fruit, structure, oak spice, and generous weight.', params_key: :cab },
  { slug: 'henschke-hill-of-grace', name: 'Henschke Hill of Grace Shiraz', region: 'Eden Valley, South Australia', color: 'Red', prompt: 'A powerful but detailed old-vine shiraz style with spice, dark berries, and firm structure.', params_key: :syrah },
  { slug: 'leeuwin-estate-art-series', name: 'Leeuwin Estate Art Series Chardonnay', region: 'Margaret River, Western Australia', color: 'White', prompt: 'Premium Margaret River chardonnay: citrus, stone fruit, creamy texture, and polished oak.', params_key: :chardonnay },
  { slug: 'grosset-polish-hill', name: 'Grosset Polish Hill Riesling', region: 'Clare Valley, South Australia', color: 'White', prompt: 'Dry Clare Valley riesling: lime, floral lift, high acidity, and a lean mineral feel.', params_key: :riesling },
  { slug: 'tyrrells-vat-1-semillon', name: "Tyrrell's Vat 1 Semillon", region: 'Hunter Valley, New South Wales', color: 'White', prompt: 'Classic Hunter semillon: light, dry, lemony, low alcohol, and very crisp when young.', params_key: :semillon },
  { slug: 'giaconda-chardonnay', name: 'Giaconda Estate Vineyard Chardonnay', region: 'Beechworth, Victoria', color: 'White', prompt: 'Intense Victorian chardonnay with citrus, stone fruit, texture, oak detail, and strong freshness.', params_key: :chardonnay },
  { slug: 'yalumba-signature', name: 'Yalumba The Signature Cabernet Shiraz', region: 'Barossa, South Australia', color: 'Red', prompt: 'Australian cabernet shiraz blend: cassis, plum, spice, firm tannin, and generous body.', params_key: :cab },
  { slug: 'tolpuddle-pinot-noir', name: 'Tolpuddle Vineyard Pinot Noir', region: 'Coal River Valley, Tasmania', color: 'Red', prompt: 'Cool-climate Tasmanian pinot: red cherry, perfume, bright acidity, fine tannin, and medium-light body.', params_key: :pinotNoir },
  { slug: 'de-bortoli-noble-one', name: 'De Bortoli Noble One Botrytis Semillon', region: 'Riverina, New South Wales', color: 'Dessert', prompt: 'Sweet botrytis semillon: honey, apricot, marmalade, rich body, and balancing acidity.', params_key: :sauternes },
  { slug: 'rockford-basket-press', name: 'Rockford Basket Press Shiraz', region: 'Barossa Valley, South Australia', color: 'Red', prompt: 'Traditional Barossa shiraz: ripe blackberry, dark plum, spice, full body, and warm alcohol.', params_key: :zinfandel },
]

wine_tests = Wine.create(australian_wine_tests_data.map { |wt|
  details = wine_details[wt[:slug]] || {}
  {
    slug: wt[:slug],
    name: wt[:name],
    region: wt[:region],
    color: wt[:color],
    prompt: wt[:prompt],
    closure: details[:closure],
    alcohol_percentage: details[:alcohol_percentage],
    volume_ml: details[:volume_ml]
  }
})

# Create wine taste parameters for test cases
wine_tests.each do |wine_test|
  line = australian_wine_tests_data.find { |item| item[:slug] == wine_test.slug }
  p[line[:params_key]].each do |slug, score|
    taste_parameter = TasteParameter.find_by(slug: slug.to_s)
    WineTasteParameter.create(
      wine: wine_test,
      taste_parameter: taste_parameter,
      score: score
    )
  end
end

# Create vintages for wine test cases
wine_tests.each do |wine|
  vintages = vintage_test_library[wine.slug] || []
  vintages.each do |v|
    Vintage.create(
      wine: wine,
      year: v[:year],
      prompt: v[:prompt]
    )
  end
end

puts "Seeds created successfully!"
puts "  - #{TasteParameter.count} taste parameters"
puts "  - #{WineProfile.count} wine profiles"
puts "  - #{WineProfileTasteParameter.count} profile taste parameters"
puts "  - #{Wine.count} wines"
puts "  - #{WineTasteParameter.count} wine taste parameters"
puts "  - #{Vintage.count} vintages"