# db/seeds.rb & wine_profiles_seed_claude.rb
# Comprehensive Wine Profiles and Taste Parameters Seed File
# Covers all major global grape varieties and structural characteristics.

puts "Cleaning existing database records..."
WineProfileTasteParameter.destroy_all
WineProfile.destroy_all

puts "Seeding wine profiles and taste parameters..."

# ==========================================
# 1. RED VARIETIES
# ==========================================

cab_sauv = WineProfile.create!(
  name: "Cabernet Sauvignon",
  category: "red",
  description: "Full-bodied red wine known for high tannins, deep color, and prominent black currant, cedar, and graphite notes."
)

WineProfileTasteParameter.create!([
  { wine_profile: cab_sauv, parameter_name: "body", value: 5 },
  { wine_profile: cab_sauv, parameter_name: "tannin", value: 5 },
  { wine_profile: cab_sauv, parameter_name: "acidity", value: 4 },
  { wine_profile: cab_sauv, parameter_name: "sweetness", value: 1 },
  { wine_profile: cab_sauv, parameter_name: "alcohol", value: 4 }
])

pinot_noir = WineProfile.create!(
  name: "Pinot Noir",
  category: "red",
  description: "Light to medium-bodied red wine with delicate tannins, high acidity, and vibrant red fruit aromas like cherry, raspberry, and earthy undertones."
)

WineProfileTasteParameter.create!([
  { wine_profile: pinot_noir, parameter_name: "body", value: 2 },
  { wine_profile: pinot_noir, parameter_name: "tannin", value: 2 },
  { wine_profile: pinot_noir, parameter_name: "acidity", value: 5 },
  { wine_profile: pinot_noir, parameter_name: "sweetness", value: 1 },
  { wine_profile: pinot_noir, parameter_name: "alcohol", value: 3 }
])

shiraz = WineProfile.create!(
  name: "Shiraz / Syrah",
  category: "red",
  description: "Bold, full-bodied red characterized by dark fruit flavors, black pepper spice, robust tannins, and a warm alcoholic finish."
)

WineProfileTasteParameter.create!([
  { wine_profile: shiraz, parameter_name: "body", value: 5 },
  { wine_profile: shiraz, parameter_name: "tannin", value: 4 },
  { wine_profile: shiraz, parameter_name: "acidity", value: 3 },
  { wine_profile: shiraz, parameter_name: "sweetness", value: 1 },
  { wine_profile: shiraz, parameter_name: "alcohol", value: 5 }
])

merlot = WineProfile.create!(
  name: "Merlot",
  category: "red",
  description: "Medium to full-bodied red wine offering soft, velvety tannins with lush plum, black cherry, and herbal characteristics."
)

WineProfileTasteParameter.create!([
  { wine_profile: merlot, parameter_name: "body", value: 4 },
  { wine_profile: merlot, parameter_name: "tannin", value: 3 },
  { wine_profile: merlot, parameter_name: "acidity", value: 3 },
  { wine_profile: merlot, parameter_name: "sweetness", value: 1 },
  { wine_profile: merlot, parameter_name: "alcohol", value: 4 }
])

malbec = WineProfile.create!(
  name: "Malbec",
  category: "red",
  description: "Deep purple, full-bodied red featuring plush tannins and intense flavors of blackberry, plum, cocoa, and sweet tobacco."
)

WineProfileTasteParameter.create!([
  { wine_profile: malbec, parameter_name: "body", value: 5 },
  { wine_profile: malbec, parameter_name: "tannin", value: 4 },
  { wine_profile: malbec, parameter_name: "acidity", value: 3 },
  { wine_profile: malbec, parameter_name: "sweetness", value: 1 },
  { wine_profile: malbec, parameter_name: "alcohol", value: 4 }
])

tempranillo = WineProfile.create!(
  name: "Tempranillo",
  category: "red",
  description: "Classic Spanish red with medium-to-full body, savory notes of leather, cherry, dried fig, and vanilla from oak aging."
)

WineProfileTasteParameter.create!([
  { wine_profile: tempranillo, parameter_name: "body", value: 4 },
  { wine_profile: tempranillo, parameter_name: "tannin", value: 4 },
  { wine_profile: tempranillo, parameter_name: "acidity", value: 3 },
  { wine_profile: tempranillo, parameter_name: "sweetness", value: 1 },
  { wine_profile: tempranillo, parameter_name: "alcohol", value: 4 }
])

sangiovese = WineProfile.create!(
  name: "Sangiovese",
  category: "red",
  description: "Italian staple red with high acidity, dusty tannins, and prominent notes of tart red cherry, tomato leaf, and oregano."
)

WineProfileTasteParameter.create!([
  { wine_profile: sangiovese, parameter_name: "body", value: 3 },
  { wine_profile: sangiovese, parameter_name: "tannin", value: 4 },
  { wine_profile: sangiovese, parameter_name: "acidity", value: 5 },
  { wine_profile: sangiovese, parameter_name: "sweetness", value: 1 },
  { wine_profile: sangiovese, parameter_name: "alcohol", value: 3 }
])

nebbiolo = WineProfile.create!(
  name: "Nebbiolo",
  category: "red",
  description: "Deceptively pale colored yet immensely powerful Italian red boasting soaring tannins, fierce acidity, and aromas of tar and roses."
)

WineProfileTasteParameter.create!([
  { wine_profile: nebbiolo, parameter_name: "body", value: 4 },
  { wine_profile: nebbiolo, parameter_name: "tannin", value: 5 },
  { wine_profile: nebbiolo, parameter_name: "acidity", value: 5 },
  { wine_profile: nebbiolo, parameter_name: "sweetness", value: 1 },
  { wine_profile: nebbiolo, parameter_name: "alcohol", value: 5 }
])

grenache = WineProfile.create!(
  name: "Grenache / Garnacha",
  category: "red",
  description: "Warm-climate red yielding high alcohol, low tannin, and luscious red fruit notes like strawberry, raspberry, and white pepper."
)

WineProfileTasteParameter.create!([
  { wine_profile: grenache, parameter_name: "body", value: 4 },
  { wine_profile: grenache, parameter_name: "tannin", value: 2 },
  { wine_profile: grenache, parameter_name: "acidity", value: 3 },
  { wine_profile: grenache, parameter_name: "sweetness", value: 1 },
  { wine_profile: grenache, parameter_name: "alcohol", value: 5 }
])


# ==========================================
# 2. WHITE VARIETIES
# ==========================================

chardonnay = WineProfile.create!(
  name: "Chardonnay",
  category: "white",
  description: "Versatile white wine ranging from crisp, lean, and mineral-driven (unoaked) to rich, buttery, and full-bodied with tropical fruit and vanilla (oaked)."
)

WineProfileTasteParameter.create!([
  { wine_profile: chardonnay, parameter_name: "body", value: 4 },
  { wine_profile: chardonnay, parameter_name: "tannin", value: 1 },
  { wine_profile: chardonnay, parameter_name: "acidity", value: 3 },
  { wine_profile: chardonnay, parameter_name: "sweetness", value: 1 },
  { wine_profile: chardonnay, parameter_name: "alcohol", value: 4 }
])

sauv_blanc = WineProfile.create!(
  name: "Sauvignon Blanc",
  category: "white",
  description: "Crisp, refreshing white wine defined by high acidity, herbaceous green aromas (grass, bell pepper), and citrus or tropical fruit notes."
)

WineProfileTasteParameter.create!([
  { wine_profile: sauv_blanc, parameter_name: "body", value: 2 },
  { wine_profile: sauv_blanc, parameter_name: "tannin", value: 1 },
  { wine_profile: sauv_blanc, parameter_name: "acidity", value: 5 },
  { wine_profile: sauv_blanc, parameter_name: "sweetness", value: 1 },
  { wine_profile: sauv_blanc, parameter_name: "alcohol", value: 3 }
])

riesling = WineProfile.create!(
  name: "Riesling",
  category: "white",
  description: "Aromatic white wine scaling from bone-dry to lusciously sweet, anchored by electric high acidity and signature lime, green apple, and petrol notes."
)

WineProfileTasteParameter.create!([
  { wine_profile: riesling, parameter_name: "body", value: 2 },
  { wine_profile: riesling, parameter_name: "tannin", value: 1 },
  { wine_profile: riesling, parameter_name: "acidity", value: 5 },
  { wine_profile: riesling, parameter_name: "sweetness", value: 2 },
  { wine_profile: riesling, parameter_name: "alcohol", value: 2 }
])

pinot_grigio = WineProfile.create!(
  name: "Pinot Grigio / Pinot Gris",
  category: "white",
  description: "Light-bodied, crisp, and clean white wine featuring light citrus, pear, and subtle white floral aromas with a refreshing finish."
)

WineProfileTasteParameter.create!([
  { wine_profile: pinot_grigio, parameter_name: "body", value: 2 },
  { wine_profile: pinot_grigio, parameter_name: "tannin", value: 1 },
  { wine_profile: pinot_grigio, parameter_name: "acidity", value: 4 },
  { wine_profile: pinot_grigio, parameter_name: "sweetness", value: 1 },
  { wine_profile: pinot_grigio, parameter_name: "alcohol", value: 3 }
])

viognier = WineProfile.create!(
  name: "Viognier",
  category: "white",
  description: "Lush, aromatic full-bodied white wine offering oily texture, low acidity, and exuberant floral notes of peach, tangerine, and honeysuckle."
)

WineProfileTasteParameter.create!([
  { wine_profile: viognier, parameter_name: "body", value: 4 },
  { wine_profile: viognier, parameter_name: "tannin", value: 1 },
  { wine_profile: viognier, parameter_name: "acidity", value: 2 },
  { wine_profile: viognier, parameter_name: "sweetness", value: 2 },
  { wine_profile: viognier, parameter_name: "alcohol", value: 4 }
])

moscato = WineProfile.create!(
  name: "Moscato",
  category: "white",
  description: "Sweet, lightly effervescent white wine characterized by intense aromas of orange blossom, peach, and ripe pear with low alcohol content."
)

WineProfileTasteParameter.create!([
  { wine_profile: moscato, parameter_name: "body", value: 1 },
  { wine_profile: moscato, parameter_name: "tannin", value: 1 },
  { wine_profile: moscato, parameter_name: "acidity", value: 3 },
  { wine_profile: moscato, parameter_name: "sweetness", value: 5 },
  { wine_profile: moscato, parameter_name: "alcohol", value: 1 }
])


# ==========================================
# 3. ROSÉ & SPARKLING VARIETIES
# ==========================================

rose = WineProfile.create!(
  name: "Dry Rosé",
  category: "rose",
  description: "Delicate pink wine made from various red grapes, balancing crisp white-wine acidity with fresh summer berry and citrus characteristics."
)

WineProfileTasteParameter.create!([
  { wine_profile: rose, parameter_name: "body", value: 2 },
  { wine_profile: rose, parameter_name: "tannin", value: 1 },
  { wine_profile: rose, parameter_name: "acidity", value: 4 },
  { wine_profile: rose, parameter_name: "sweetness", value: 1 },
  { wine_profile: rose, parameter_name: "alcohol", value: 3 }
])

sparkling = WineProfile.create!(
  name: "Sparkling / Champagne",
  category: "sparkling",
  description: "Effervescent wine defined by lively carbonation bubbles, high refreshing acidity, and complex brioche, green apple, and chalky mineral notes."
)

WineProfileTasteParameter.create!([
  { wine_profile: sparkling, parameter_name: "body", value: 2 },
  { wine_profile: sparkling, parameter_name: "tannin", value: 1 },
  { wine_profile: sparkling, parameter_name: "acidity", value: 5 },
  { wine_profile: sparkling, parameter_name: "sweetness", value: 1 },
  { wine_profile: sparkling, parameter_name: "alcohol", value: 3 }
])

puts "Successfully seeded #{WineProfile.count} wine profiles and #{WineProfileTasteParameter.count} taste parameters!"