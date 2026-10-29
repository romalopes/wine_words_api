# frozen_string_literal: true
# db/seeds/wine_profile_seed_consolidated.rb
# Non-destructive, repeatable seed for WineProfile and WineProfileTasteParameter.
# Preserves the original 69 profile slugs and their six scores; adds core varieties.
# Scores are editorial 1-5 style estimates, not measurements of individual bottles.

# Sweetness: dry, off-dry, medium-dry, medium-sweet, sweet
# Acidity: low, medium(-), medium, medium(+), high
# Tannin: low, medium(-), medium, medium(+), high
# Alcohol: low, medium(-), medium, medium(+), high
# Body: light, medium(-), medium, medium(+), full
# Fruit intensity: light, medium(-), medium, medium(+), pronounced

PARAMETER_ATTRIBUTES = {
  sweetness: { label: 'Sweetness', label_1: 'Dry', label_2: 'Off-dry', label_3: 'Medium-dry', label_4: 'Medium-sweet', label_5: 'Sweet', help: 'How much sugar or ripe sweetness you perceive.' },
  acidity: { label: 'Acidity', label_1: 'Low', label_2: 'Medium (-)', label_3: 'Medium', label_4: 'Medium (+)', label_5: 'High', help: 'How bright, fresh, or mouth-watering the wine feels.' },
  tannin: { label: 'Tannin', label_1: 'Low', label_2: 'Medium (-)', label_3: 'Medium', label_4: 'Medium (+)', label_5: 'High', help: 'The drying texture, common in red wines.' },
  alcohol: { label: 'Alcohol warmth', label_1: 'Low', label_2: 'Medium (-)', label_3: 'Medium', label_4: 'Medium (+)', label_5: 'High', help: 'The heat or weight from alcohol.' },
  body: { label: 'Body', label_1: 'Light', label_2: 'Medium (-)', label_3: 'Medium', label_4: 'Medium (+)', label_5: 'Full', help: 'The weight and richness of the wine on your palate.' },
  fruit: { label: 'Fruit intensity', label_1: 'Light', label_2: 'Medium (-)', label_3: 'Medium', label_4: 'Medium (+)', label_5: 'Pronounced', help: 'How strongly fruit aromas and flavors stand out.' }
}.freeze
PARAMETERS = PARAMETER_ATTRIBUTES.keys.freeze
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
  # Additional core international and regional grape varieties
  ["grenache","Grenache / Garnacha","Red","Grenache","Southern Rhone|Aragon|McLaren Vale","strawberry|raspberry|white pepper|herbs","Pairs with lamb, ratatouille and grilled vegetables.",[3,4,2,1,4,5]],
  ["cabernet-franc","Cabernet Franc","Red","Cabernet Franc","Loire Valley|Bordeaux|Ontario","raspberry|violet|bell pepper|graphite","Pairs with roast poultry and herb dishes.",[4,3,3,1,3,3]],
  ["mourvedre","Mourvedre / Monastrell","Red","Mourvedre","Bandol|Jumilla|McLaren Vale","blackberry|game|pepper|leather","Pairs with lamb and slow-cooked meats.",[3,5,5,1,4,4]],
  ["carignan","Carignan / Carinena","Red","Carignan","Languedoc|Priorat|Sardinia","black cherry|herbs|licorice|earth","Pairs with rustic stews and grilled meat.",[4,4,4,1,3,4]],
  ["montepulciano","Montepulciano","Red","Montepulciano","Abruzzo|Marche","black cherry|plum|oregano|spice","Pairs with tomato pasta and grilled sausages.",[3,4,3,1,3,4]],
  ["barbera","Barbera","Red","Barbera","Piedmont|Asti|Alba","sour cherry|plum|violet|spice","Pairs with pizza and tomato pasta.",[5,3,2,1,3,4]],
  ["dolcetto","Dolcetto","Red","Dolcetto","Piedmont|Dogliani","black cherry|almond|violet|licorice","Pairs with salumi and mushroom pasta.",[3,3,3,1,3,4]],
  ["aglianico","Aglianico","Red","Aglianico","Taurasi|Vulture|Campania","black cherry|smoke|leather|herbs","Pairs with braised beef and aged cheese.",[4,5,5,1,4,4]],
  ["nero-davola","Nero d'Avola","Red","Nero d'Avola","Sicily","black plum|cherry|spice|herbs","Pairs with aubergine and grilled meat.",[3,4,3,1,4,4]],
  ["primitivo","Primitivo","Red","Primitivo","Puglia|Manduria","blackberry|jam|pepper|licorice","Pairs with barbecue and rich pasta.",[3,5,3,1,5,5]],
  ["bobal","Bobal","Red","Bobal","Utiel-Requena|Manchuela","blackberry|violet|herbs|earth","Pairs with roast lamb and grilled vegetables.",[4,4,4,1,3,4]],
  ["mencia","Mencia","Red","Mencia","Bierzo|Ribeira Sacra","red cherry|violet|slate|herbs","Pairs with mushrooms and roast poultry.",[4,3,3,1,3,3]],
  ["tannat","Tannat","Red","Tannat","Madiran|Uruguay","blackberry|cocoa|smoke|plum","Pairs with grilled beef and rich stews.",[3,5,5,1,4,4]],
  ["petit-verdot","Petit Verdot","Red","Petit Verdot","Bordeaux|Australia|Spain","blackcurrant|violet|cedar|spice","Pairs with steak and lamb.",[3,5,5,1,4,4]],
  ["carmenere","Carmenere","Red","Carmenere","Colchagua|Maipo|Chile","black plum|paprika|herbs|chocolate","Pairs with grilled meats and peppers.",[3,4,3,1,3,4]],
  ["touriga-nacional","Touriga Nacional","Red","Touriga Nacional","Douro|Dao|Alentejo","blackberry|violet|bergamot|spice","Pairs with roast lamb and beef.",[4,5,4,1,4,5]],
  ["nerello-mascalese","Nerello Mascalese","Red","Nerello Mascalese","Etna|Sicily","red cherry|smoke|herbs|mineral","Pairs with tuna and mushroom dishes.",[5,3,4,1,3,3]],
  ["zweigelt","Zweigelt","Red","Zweigelt","Austria|Burgenland","sour cherry|raspberry|pepper|violet","Pairs with roast chicken and charcuterie.",[4,3,2,1,3,4]],
  ["blaufrankisch","Blaufrankisch","Red","Blaufrankisch","Burgenland|Hungary","black cherry|pepper|violet|earth","Pairs with duck and game.",[4,4,3,1,3,4]],
  ["pinot-meunier","Pinot Meunier","Red","Pinot Meunier","Champagne|England|Australia","red apple|cherry|floral|spice","Pairs with poultry and soft cheese.",[4,2,2,1,2,3]],
  ["airen","Airen","White","Airen","La Mancha|Castilla-La Mancha","apple|pear|citrus|herbs","Pairs with tapas and light fish.",[3,2,1,1,2,2]],
  ["trebbiano","Trebbiano / Ugni Blanc","White","Trebbiano Toscano","Tuscany|Abruzzo|Cognac","lemon|green apple|almond|herbs","Pairs with shellfish and simple salads.",[4,2,1,1,2,2]],
  ["macabeo","Macabeo / Viura","White","Macabeo","Rioja|Penedes|Catalonia","apple|citrus|fennel|almond","Pairs with seafood and tapas.",[4,2,1,1,2,3]],
  ["xarel-lo","Xarel-lo","White","Xarel-lo","Penedes|Catalonia","lemon|pear|fennel|saline","Pairs with seafood and rice dishes.",[4,3,1,1,3,3]],
  ["parellada","Parellada","White","Parellada","Catalonia|Penedes","green apple|citrus|white flowers|herbs","Pairs with light seafood and salads.",[4,1,1,1,2,2]],
  ["glera","Glera","White","Glera","Veneto|Friuli","pear|apple|white flowers|melon","Pairs with aperitivo and light starters.",[4,2,1,1,2,3]],
  ["muscadet-melon","Melon de Bourgogne","White","Melon de Bourgogne","Muscadet|Loire Valley","lemon|green apple|saline|yeast","Pairs with oysters and mussels.",[5,2,1,1,2,2]],
  ["vermentino","Vermentino","White","Vermentino","Sardinia|Corsica|Liguria","grapefruit|pear|herbs|saline","Pairs with grilled fish and pesto.",[4,3,1,1,3,3]],
  ["fiano","Fiano","White","Fiano","Campania|Avellino|McLaren Vale","pear|hazelnut|honey|citrus","Pairs with roast chicken and seafood.",[4,3,1,1,3,3]],
  ["greco","Greco","White","Greco","Campania|Greco di Tufo","lemon|peach|almond|mineral","Pairs with fish and creamy pasta.",[4,3,1,1,3,3]],
  ["garganega","Garganega","White","Garganega","Soave|Veneto","pear|chamomile|almond|citrus","Pairs with risotto and white fish.",[4,3,1,1,2,3]],
  ["cortese","Cortese","White","Cortese","Gavi|Piedmont","lemon|green apple|almond|white flowers","Pairs with seafood and antipasti.",[5,2,1,1,2,2]],
  ["arinto","Arinto","White","Arinto","Bucelas|Vinho Verde|Alentejo","lime|green apple|saline|herbs","Pairs with grilled sardines and shellfish.",[5,2,1,1,2,3]],
  ["loureiro","Loureiro","White","Loureiro","Vinho Verde|Minho","lime|orange blossom|bay leaf|peach","Pairs with seafood and salads.",[5,2,1,1,2,4]],
  ["alvarinho","Alvarinho","White","Alvarinho","Moncao e Melgaco|Vinho Verde","peach|lime|orange blossom|saline","Pairs with shellfish and grilled fish.",[5,3,1,1,3,4]],
  ["antao-vaz","Antao Vaz","White","Antao Vaz","Alentejo","tropical fruit|citrus|herbs|melon","Pairs with roast fish and poultry.",[3,4,1,1,4,4]],
  ["rkatsiteli","Rkatsiteli","White","Rkatsiteli","Kakheti|Georgia","green apple|quince|herbs|citrus","Pairs with herbs, cheese and poultry.",[4,3,1,1,3,3]],
  ["furmint","Furmint","White","Furmint","Tokaj|Somlo","green apple|pear|smoke|quince","Pairs with pork, poultry and cheese.",[5,3,1,1,3,3]],
  ["harslevelu","Harslevelu","White","Harslevelu","Tokaj|Hungary","linden blossom|pear|honey|spice","Pairs with roast poultry and soft cheese.",[4,3,1,2,3,4]],
  ["grasevina","Grasevina / Welschriesling","White","Grasevina","Croatia|Austria|Hungary","green apple|citrus|flowers|almond","Pairs with freshwater fish and salads.",[4,2,1,1,2,3]],
  ["catarratto","Catarratto","White","Catarratto","Sicily","lemon|orange blossom|herbs|almond","Pairs with seafood and vegetable dishes.",[4,2,1,1,3,3]],
  ["muscat-blanc","Muscat Blanc a Petits Grains","White","Muscat Blanc a Petits Grains","Alsace|Piedmont|Rutherglen","grape|orange blossom|rose|peach","Pairs with fruit and aromatic dishes.",[3,2,1,2,2,5]],
  ["palomino","Palomino Fino","White","Palomino","Jerez|Andalusia","apple|almond|bread dough|saline","Pairs with olives, almonds and seafood.",[3,2,1,1,2,2]],
  ["pedro-ximenez","Pedro Ximenez","Dessert","Pedro Ximenez","Montilla-Moriles|Jerez","raisin|fig|molasses|coffee","Pairs with blue cheese and desserts.",[2,5,1,5,4,5]],
  ["marsanne","Marsanne","White","Marsanne","Northern Rhone|Victoria","pear|honeysuckle|almond|wax","Pairs with roast chicken and creamy dishes.",[3,4,1,1,3,3]],
  ["roussanne","Roussanne","White","Roussanne","Northern Rhone|Savoie|Victoria","apricot|herbs|pear|honey","Pairs with poultry and seafood.",[4,4,1,1,3,4]],
  ["picpoul","Picpoul Blanc","White","Picpoul Blanc","Picpoul de Pinet|Languedoc","lemon|green apple|saline|herbs","Pairs with oysters and shellfish.",[5,2,1,1,2,3]],
  ["godello","Godello","White","Godello","Valdeorras|Bierzo","pear|lemon|stone|fennel","Pairs with grilled fish and poultry.",[4,3,1,1,3,3]],
  ["silvaner","Silvaner","White","Silvaner","Franken|Alsace","pear|herbs|earth|apple","Pairs with asparagus and vegetables.",[3,2,1,1,2,2]],
  ["scheurebe","Scheurebe","White","Scheurebe","Pfalz|Rheinhessen","grapefruit|blackcurrant|passionfruit|flowers","Pairs with spicy dishes and soft cheese.",[4,2,1,2,2,5]],
  ["vidal-blanc","Vidal Blanc","White","Vidal Blanc","Ontario|Finger Lakes","pineapple|apricot|honey|citrus","Pairs with fruit desserts and blue cheese.",[5,3,1,3,2,4]],
  ["saperavi","Saperavi","Red","Saperavi","Kakheti|Georgia","blackberry|plum|earth|spice","Pairs with grilled lamb and stews.",[4,5,5,1,4,4]],
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

normalized_slugs = ROWS.map { |row| row.first.to_s.strip.downcase }
raise 'Duplicate wine profile slugs' unless normalized_slugs.uniq.size == ROWS.size
raise 'Missing wine profile slug' if normalized_slugs.any?(&:empty?)

ActiveRecord::Base.transaction do
  parameters = PARAMETER_ATTRIBUTES.to_h do |slug, attributes|
    parameter = TasteParameter.find_or_initialize_by(slug: slug.to_s)
    parameter.assign_attributes(attributes)
    parameter.save!
    [slug, parameter]
  end

  # unknown_country = Country.find_or_create_by!(name: 'Unknown Country', code: 'UN')

  ROWS.each do |slug, name, color, grapes, regions, notes, serving, scores|
    raise "Invalid scores for #{slug}" unless scores.length == PARAMETERS.length && scores.all? { |n| (1..5).cover?(n) }
    profile = WineProfile.find_or_initialize_by(slug: slug.to_s.strip.downcase)
    profile.assign_attributes(name: name, color: color, notes: notes.split('|').to_json,
                              serving: serving)
    puts "Seeding wine profile: #{slug} (#{name})"

    grapes_array = []
    puts "  - Grapes: #{grapes}"
    grapes.split('|').each do |grape|
      current_grape = Grape.find_by_name_or_synonym(grape.strip)
      # current_grape = Grape.create!(name: grape.strip) unless current_grape
      if current_grape
        profile.profile_grapes << current_grape unless profile.profile_grapes.include?(current_grape)
      else
        puts "  - Grape \"#{grape.strip}\" not found. Skipping association."
        grapes_array << grape
      end
    end
    puts "grapes_array: #{grapes_array}"

    regions_array = []
    puts "  - Regions: #{regions}"
    regions.split('|').each do |region|
      normalized = region.strip
      current_region = Region.where("name ILIKE ?", normalized).first ||
                       Region.where("name ILIKE ?", "%#{normalized}%").order(:name).first
      if current_region
        profile.profile_regions << current_region unless profile.profile_regions.include?(current_region)
      else
        puts "  - Region \"#{region.strip}\" not found. Skipping association."
        regions_array << region
      end
    end
    # Keep the array columns to save the non canonical names
    profile.grapes = grapes_array unless grapes_array.empty?
    profile.regions = regions_array unless regions_array.empty?

    profile.save!
    puts "  - Saved wine profile: #{profile.slug} (#{profile.name})"
    PARAMETERS.zip(scores).each do |key, score|
      join = WineProfileTasteParameter.find_or_initialize_by(wine_profile: profile, taste_parameter: parameters.fetch(key))
      join.score = score
      join.save!
    end
  end
end
puts "Seeded #{ROWS.size} wine profiles and #{ROWS.size * PARAMETERS.size} taste scores."
