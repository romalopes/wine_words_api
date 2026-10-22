# frozen_string_literal: true
# db/wine_profiles_seed.rb
# Non-destructive, repeatable seed for WineProfile and WineProfileTasteParameter.
# Preserves all 34 existing profile slugs and their original six scores.
# Scores are editorial 1-5 style estimates, not measurements of individual bottles.

PARAMETERS = %i[acidity body tannin sweetness alcohol fruit].freeze
# slug | name | color | grapes | regions | notes | serving | scores in PARAMETERS order
ROWS = [
  ['pinot-noir','Pinot Noir','Red','Pinot Noir','Burgundy|Oregon|New Zealand','cherry|raspberry|earth|violet','Great with roast chicken, mushrooms, salmon, and charcuterie.',[4,2,2,1,2,3]],
  ['cabernet-sauvignon','Cabernet Sauvignon','Red','Cabernet Sauvignon','Bordeaux|Napa Valley|Coonawarra','blackcurrant|cedar|graphite|mint','Built for steak, lamb, hard cheeses, and richer sauces.',[3,5,5,1,4,4]],
  ['merlot','Merlot','Red','Merlot','Right Bank Bordeaux|Washington State|Chile','plum|black cherry|cocoa|bay leaf','Easy with burgers, roast pork, tomato pasta, and soft cheeses.',[3,4,3,1,3,4]],
  ['syrah-shiraz','Syrah / Shiraz','Red','Syrah|Shiraz','Northern Rhone|Barossa Valley|McLaren Vale','blackberry|pepper|smoke|olive','Strong match for barbecue, grilled vegetables, lamb, and spices.',[3,5,4,1,4,5]],
  ['sangiovese','Sangiovese','Red','Sangiovese','Chianti|Brunello di Montalcino|Tuscany','red cherry|tomato leaf|dried herbs|leather','A natural partner for pizza, pasta, ragu, and grilled meats.',[5,3,4,1,3,3]],
  ['chardonnay','Chardonnay','White','Chardonnay','Burgundy|California|Margaret River','apple|citrus|butter|vanilla','Works with roast chicken, creamy sauces, seafood, and corn.',[3,4,1,1,3,3]],
  ['sauvignon-blanc','Sauvignon Blanc','White','Sauvignon Blanc','Marlborough|Loire Valley|Adelaide Hills','lime|passionfruit|grass|gooseberry','Bright with goat cheese, salads, prawns, herbs, and citrus.',[5,2,1,1,2,4]],
  ['riesling','Riesling','White','Riesling','Mosel|Clare Valley|Alsace','lime|green apple|jasmine|petrol','Excellent with spicy food, pork, seafood, and salty snacks.',[5,2,1,3,2,4]],
  ['prosecco','Prosecco','Sparkling','Glera','Veneto|Friuli','pear|apple blossom|melon|lemon','Pour with brunch, fried snacks, fresh fruit, and aperitivo plates.',[4,1,1,2,1,4]],
  ['rose','Dry Rose','Rose','Grenache|Cinsault|Syrah','Provence|Bandol|South Australia','strawberry|watermelon|citrus|white flowers','Flexible with seafood, picnic food, grilled chicken, and mezze.',[4,2,1,1,2,3]],
  ['tempranillo','Tempranillo','Red','Tempranillo','Rioja|Ribera del Duero|Toro','red cherry|dried fig|tobacco|leather','Pairs with grilled lamb, chorizo, manchego, and beef stew.',[4,4,4,1,3,4]],
  ['malbec','Malbec','Red','Malbec','Mendoza|Cahors|Patagonia','plum|blackberry|violet|cocoa','Perfect with grilled steak, empanadas, barbecue, and blue cheese.',[3,5,4,1,4,5]],
  ['zinfandel','Zinfandel','Red','Zinfandel','Sonoma|Napa Valley|Paso Robles','brambleberry|jammy fruit|black pepper|vanilla','Great with pulled pork, ribs, smoky barbecue, and pizza.',[3,5,4,2,5,5]],
  ['nebbiolo','Nebbiolo','Red','Nebbiolo','Piedmont|Barolo|Barbaresco','tar|rose|dried cherry|truffle','Matches braised beef, risotto, aged hard cheese, and truffle dishes.',[4,4,5,1,4,3]],
  ['gamay','Gamay (Beaujolais)','Red','Gamay','Beaujolais|Loire Valley','red berry|banana|candy|floral','Lively with charcuterie, roasted chicken, soft cheeses, and salads.',[4,2,2,1,2,4]],
  ['pinot-grigio','Pinot Grigio','White','Pinot Grigio','Friuli|Trentino|Veneto','lemon zest|green apple|pear|almond','Clean with seafood pasta, oysters, light salads, and caprese.',[4,2,1,1,2,3]],
  ['pinot-gris','Pinot Gris','White','Pinot Gris','Alsace|Oregon|New Zealand','pear|honey|stone fruit|spice','Versatile with roast pork, asian cuisine, soft cheeses, and pumpkin.',[3,3,1,2,3,4]],
  ['viognier','Viognier','White','Viognier','Condrieu|Margaret River|Virginia','apricot|peach|honeysuckle|ginger','Lovely with lobster, scallops, spicy curries, and roast chicken.',[3,4,1,2,4,5]],
  ['gewurztraminer','Gewurztraminer','White','Gewurztraminer','Alsace|Pfalz|Marlborough','lychee|rose petal|turkish delight|ginger','Stunning with thai food, indian curries, smoked salmon, and strong cheese.',[3,4,1,3,4,5]],
  ['chenin-blanc','Chenin Blanc','White','Chenin Blanc','Loire Valley|Stellenbosch|California','quince|honeydew|chamomile|wet stone','Bright with roast chicken, pork, goat cheese, and vegetable tarts.',[5,3,1,2,2,3]],
  ['semillon','Semillon','White','Semillon','Hunter Valley|Bordeaux|Margaret River','lemon curd|beeswax|lanolin|toast','Classic with roast chicken, seafood, and creamy pasta.',[4,2,1,1,2,2]],
  ['gruner-veltliner','Gruner Veltliner','White','Gruner Veltliner','Wachau|Kamptal|Kremstal','white pepper|green pea|lime|lentil','Beautifully matches schnitzel, asparagus, sushi, and fresh salads.',[4,3,1,1,3,3]],
  ['albarino','Albarino','White','Albarino','Rias Baixas|Moncao|Bairrada','saline|citrus peel|white peach|jasmine','Brilliant with grilled octopus, ceviche, sushi, and briny shellfish.',[5,2,1,1,2,4]],
  ['verdejo','Verdejo','White','Verdejo','Rueda|La Mancha','fennel|grapefruit|broom flower|cut grass','Cuts through garlic prawns, paella, grilled vegetables, and tapas.',[4,2,1,1,2,3]],
  ['champagne','Champagne','Sparkling','Chardonnay|Pinot Noir|Pinot Meunier','Champagne','brioche|citrus|green apple|chalk','Pour with oysters, caviar, fried chicken, and celebration toasts.',[5,2,1,1,3,3]],
  ['cava','Cava','Sparkling','Macabeo|Parellada|Xarel.lo','Penedes|Catalonia','green apple|almond|toast|lemon','Lively with patatas bravas, jamon, seafood, and fried snacks.',[4,2,1,1,2,3]],
  ['franciacorta','Franciacorta','Sparkling','Chardonnay|Pinot Nero','Lombardy|Franciacorta','almond paste|white peach|lemon curd|biscuit','Refined with cured meats, sushi, seafood risotto, and aperitivo.',[4,3,1,1,3,3]],
  ['moscato-d-asti',"Moscato d'Asti",'Dessert','Moscato Bianco','Asti|Piedmont','orange blossom|peach|honey|grape','Luscious with panettone, fresh fruit, panna cotta, and pastries.',[4,2,1,5,1,5]],
  ['sauternes','Sauternes','Dessert','Semillon|Sauvignon Blanc|Muscadelle','Bordeaux|Sauternes|Barsac','apricot|honey|ginger|beeswax','Decadent with foie gras, blue cheese, tarte tatin, and creme brulee.',[4,4,1,5,3,5]],
  ['port-tawny','Tawny Port','Dessert','Touriga Nacional|Touriga Franca|Tinta Roriz','Douro Valley','dried fig|caramel|walnut|orange peel','Wonderful with stilton, chocolate desserts, and toasted nuts.',[3,4,3,5,4,4]],
  ['sherry-oloroso','Oloroso Sherry','Dessert','Palomino','Jerez|Andalusia','walnut|toffee|cinnamon|dried orange','Sip with aged manchego, olives, almonds, and rich stews.',[3,4,1,2,5,3]],
  ['pinotage','Pinotage','Red','Pinotage','Stellenbosch|Franschhoek|Swartland','smoked meat|plum|banana|earthy spice','Barbecue champion - pairs with boerewors, lamb chops, and grilled meats.',[3,4,3,1,4,4]],
  ['torrontes','Torrontes','White','Torrontes','Salta|Mendoza|Cafayate','grapefruit|rose|lychee|herbal lift','Vivid with ceviche, grilled fish, empanadas, and spicy latin cuisine.',[4,2,1,1,3,5]],
  ['sangiovese-blend-super-tuscan','Super Tuscan Blend','Red','Sangiovese|Cabernet Sauvignon|Merlot','Tuscany|Bolgheri','dark cherry|cedar|leather|tobacco','Great with bistecca alla fiorentina, rich pasta, and aged pecorino.',[4,5,4,1,4,4]],
  # Additional regional and stylistic profiles
  ['hunter-valley-semillon','Hunter Valley Semillon','White','Semillon','Hunter Valley','lemon|lime|grass|toast','Excellent with oysters, prawns, and seafood.',[5,1,1,1,1,2]],
  ['aged-hunter-valley-semillon','Aged Hunter Valley Semillon','White','Semillon','Hunter Valley','toast|honey|lanolin|lemon curd','Try with roast chicken and richer seafood.',[4,3,1,1,1,3]],
  ['margaret-river-semillon-sauvignon-blanc','Margaret River Semillon Sauvignon Blanc','White','Semillon|Sauvignon Blanc','Margaret River','lemon|passionfruit|herbs|grass','Pair with fish, salads, and fresh goat cheese.',[4,3,1,1,2,4]],
  ['mendoza-malbec','Mendoza Malbec','Red','Malbec','Mendoza|Uco Valley','black plum|violet|blackberry|cocoa','Pair with asado, steak, and empanadas.',[3,5,4,1,4,5]],
  ['cahors-malbec','Cahors Malbec','Red','Malbec','Cahors','blackcurrant|earth|violet|cedar','Excellent with duck, lamb, and cassoulet.',[4,4,5,1,3,3]],
  ['barossa-shiraz','Barossa Valley Shiraz','Red','Shiraz','Barossa Valley','blackberry|plum|chocolate|licorice','Serve with grilled beef and barbecue.',[3,5,4,1,5,5]],
  ['northern-rhone-syrah','Northern Rhone Syrah','Red','Syrah','Hermitage|Cote-Rotie|Saint-Joseph','black pepper|violet|olive|blackberry','Serve with lamb, mushrooms, and game.',[4,4,4,1,3,4]],
  ['coonawarra-cabernet-sauvignon','Coonawarra Cabernet Sauvignon','Red','Cabernet Sauvignon','Coonawarra','blackcurrant|mint|cedar|eucalyptus','Ideal with roast lamb and steak.',[4,4,5,1,4,4]],
  ['margaret-river-cabernet-sauvignon','Margaret River Cabernet Sauvignon','Red','Cabernet Sauvignon','Margaret River','cassis|bay leaf|cedar|violet','Great with beef and slow-cooked lamb.',[4,4,4,1,3,4]],
  ['clare-valley-dry-riesling','Clare Valley Dry Riesling','White','Riesling','Clare Valley','lime|lemon|floral|mineral','Pairs with oysters, spicy dishes, and seafood.',[5,2,1,1,2,4]],
  ['eden-valley-riesling','Eden Valley Riesling','White','Riesling','Eden Valley','lime|jasmine|green apple|slate','Pair with shellfish and Asian dishes.',[5,2,1,1,2,3]],
  ['mosel-off-dry-riesling','Mosel Off-Dry Riesling','White','Riesling','Mosel','green apple|peach|slate|lime','Great with spicy Thai food and pork.',[5,2,1,3,1,4]],
  ['marlborough-sauvignon-blanc','Marlborough Sauvignon Blanc','White','Sauvignon Blanc','Marlborough','passionfruit|gooseberry|lime|grass','Ideal with salads, seafood, and goat cheese.',[5,2,1,1,2,5]],
  ['sancerre-sauvignon-blanc','Sancerre Sauvignon Blanc','White','Sauvignon Blanc','Sancerre|Loire Valley','lemon|flint|grass|gooseberry','Try with oysters and goat cheese.',[5,2,1,1,2,3]],
  ['chablis-chardonnay','Chablis Chardonnay','White','Chardonnay','Chablis|Burgundy','lemon|green apple|chalk|oyster shell','Excellent with oysters and white fish.',[5,2,1,1,2,3]],
  ['margaret-river-chardonnay','Margaret River Chardonnay','White','Chardonnay','Margaret River','white peach|lemon|cashew|flint','Pair with roast chicken and seafood.',[4,4,1,1,3,4]],
  ['tasmanian-pinot-noir','Tasmanian Pinot Noir','Red','Pinot Noir','Tasmania|Coal River Valley','cherry|raspberry|rose|earth','Pair with duck, salmon, and mushrooms.',[5,3,2,1,2,4]],
  ['burgundy-pinot-noir','Red Burgundy Pinot Noir','Red','Pinot Noir','Burgundy','red cherry|earth|violet|forest floor','Pairs with poultry and mushroom dishes.',[4,3,3,1,3,3]],
  ['rioja-reserva','Rioja Reserva','Red','Tempranillo|Garnacha|Graciano','Rioja','cherry|vanilla|tobacco|leather','Serve with lamb, chorizo, and aged cheese.',[4,4,4,1,3,3]],
  ['barolo-nebbiolo','Barolo Nebbiolo','Red','Nebbiolo','Barolo|Piedmont','rose|tar|cherry|truffle','Pairs with braised beef and truffle risotto.',[5,4,5,1,4,3]],
  ['chianti-classico','Chianti Classico','Red','Sangiovese','Chianti Classico|Tuscany','sour cherry|herbs|leather|violet','Perfect with tomato pasta and grilled meat.',[5,3,4,1,3,3]],
  ['provence-rose','Provence Dry Rose','Rose','Grenache|Cinsault|Syrah','Provence','strawberry|citrus|melon|herbs','Serve with seafood, salads, and mezze.',[4,2,1,1,2,3]],
  ['brut-nature-champagne','Champagne Brut Nature','Sparkling','Chardonnay|Pinot Noir|Pinot Meunier','Champagne','lemon|chalk|brioche|apple','Excellent with oysters and seafood.',[5,2,1,1,3,3]],
  ['fino-sherry','Fino Sherry','Fortified','Palomino','Jerez','almond|bread dough|saline|green olive','Serve chilled with olives, almonds, and seafood.',[3,2,1,1,4,2]],
  ['ruby-port','Ruby Port','Fortified','Touriga Nacional|Touriga Franca|Tinta Roriz','Douro Valley','blackberry|plum|chocolate|spice','Pair with dark chocolate and blue cheese.',[3,5,4,5,5,5]],
  ['riverina-botrytis-semillon','Riverina Botrytis Semillon','Dessert','Semillon','Riverina','apricot|marmalade|honey|ginger','Pairs with blue cheese and fruit desserts.',[4,5,1,5,2,5]],
  ['alentejo-touriga-nacional','Alentejo Touriga Nacional','Red','Touriga Nacional','Alentejo','blackberry|violet|plum|spice','Serve with lamb and roasted meats.',[3,5,4,1,4,5]],
  ['douro-red-blend','Douro Red Blend','Red','Touriga Nacional|Touriga Franca|Tinta Roriz','Douro Valley','black cherry|violet|schist|spice','Great with grilled meats and hearty stews.',[4,5,4,1,4,4]],
  ['etna-rosso','Etna Rosso','Red','Nerello Mascalese|Nerello Cappuccio','Mount Etna|Sicily','red cherry|smoke|herbs|mineral','Pair with grilled tuna and mushroom dishes.',[5,3,4,1,3,3]],
  ['assyrtiko-santorini','Santorini Assyrtiko','White','Assyrtiko','Santorini','lemon|salt|flint|green apple','Ideal with grilled fish and seafood.',[5,3,1,1,3,3]],
  ['verdejo-rueda','Rueda Verdejo','White','Verdejo','Rueda','grapefruit|fennel|herbs|peach','Great with tapas and garlic prawns.',[4,3,1,1,3,4]],
  ['vouvray-dry-chenin','Vouvray Sec Chenin Blanc','White','Chenin Blanc','Vouvray|Loire Valley','quince|apple|chamomile|wet stone','Pairs with roast poultry and goat cheese.',[5,3,1,1,2,3]],
  ['amarone-valpolicella','Amarone della Valpolicella','Red','Corvina|Corvinone|Rondinella','Valpolicella|Veneto','dried cherry|fig|chocolate|spice','Try with aged cheese and slow-cooked beef.',[3,5,4,2,5,5]],
  ['brunello-montalcino','Brunello di Montalcino','Red','Sangiovese','Montalcino|Tuscany','cherry|leather|tobacco|herbs','Pairs with roast lamb and porcini.',[5,4,5,1,4,4]],
  ['priorat-red','Priorat Red Blend','Red','Garnacha|Carinena','Priorat','blackberry|licorice|slate|herbs','Serve with lamb and grilled meat.',[3,5,4,1,5,5]]
].freeze

raise 'Duplicate wine profile slugs' unless ROWS.map(&:first).uniq.size == ROWS.size

ActiveRecord::Base.transaction do
  parameters = PARAMETERS.to_h do |slug|
    [slug, TasteParameter.find_by!(slug: slug.to_s)]
  end

  ROWS.each do |slug, name, color, grapes, regions, notes, serving, scores|
    raise "Invalid scores for #{slug}" unless scores.length == PARAMETERS.length && scores.all? { |n| (1..5).cover?(n) }
    profile = WineProfile.find_or_initialize_by(slug: slug)
    profile.assign_attributes(name: name, color: color, grapes: grapes.split('|').to_json,
                              regions: regions.split('|').to_json, notes: notes.split('|').to_json,
                              serving: serving)
    profile.save!
    PARAMETERS.zip(scores).each do |key, score|
      join = WineProfileTasteParameter.find_or_initialize_by(wine_profile: profile, taste_parameter: parameters.fetch(key))
      join.score = score
      join.save!
    end
  end
end
puts "Seeded #{ROWS.size} wine profiles and #{ROWS.size * PARAMETERS.size} taste scores."
