# db/seeds/wine_seeds.rb
#
# Seeds Wine records for each producer provided in producer_seeds.rb
# (Minimum 2 wines per producer)
#
# Usage: rails runner db/seeds/wine_seeds.rb

WINE_SEEDS = [
  # --- Pedlidis ---
  {
    name: "Pedlidis Single Vineyard Riesling",
    slug: "pedlidis-single-vineyard-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "A vibrant Barossa Valley Riesling with intense lime juice and minerality.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Pedlidis",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Pedlidis Old Vine Shiraz Grenache",
    slug: "pedlidis-old-vine-shiraz-grenache",
    color: "Red",
    closure: "Cork",
    prompt: "Rich and complex red blend displaying spicy dark berries and soft tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Pedlidis",
    sparkling: false,
    grapes: ["Shiraz", "Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Alkina Wine Estate ---
  {
    name: "Alkina Kin Grenache",
    slug: "alkina-kin-grenache",
    color: "Red",
    closure: "Cork",
    prompt: "A delicate, aromatic Grenache full of red cherry and herbal spice notes.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Alkina Wine Estate",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Alkina Night Sky GSM",
    slug: "alkina-night-sky-gsm",
    color: "Red",
    closure: "Cork",
    prompt: "Layered organic blend of Grenache, Shiraz, and Mataro with earthy complexity.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Alkina Wine Estate",
    sparkling: false,
    grapes: ["Grenache", "Shiraz", "Mataro"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Sami-Odi ---
  {
    name: "Sami-Odi Little Wine #11",
    slug: "sami-odi-little-wine-11",
    color: "Red",
    closure: "Cork",
    prompt: "Unfiltered multi-vintage expression of Syrah with exceptional texture and depth.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Sami-Odi",
    sparkling: false,
    grapes: ["Syrah"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Sami-Odi Hoffmann Dallwitz Syrah",
    slug: "sami-odi-hoffmann-dallwitz-syrah",
    color: "Red",
    closure: "Cork",
    prompt: "Single-vineyard expression showcasing pure violet, black plum, and ironstone notes.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Sami-Odi",
    sparkling: false,
    grapes: ["Syrah"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Marco Lubiana ---
  {
    name: "Marco Lubiana Huon Valley Chardonnay",
    slug: "marco-lubiana-huon-valley-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Cool-climate Chardonnay with flinty reduction, lemon curd, and driving acidity.",
    alcohol_percentage: 12.8,
    volume_ml: 750,
    producer_name: "Marco Lubiana",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Huon Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Marco Lubiana Derwent Valley Pinot Noir",
    slug: "marco-lubiana-derwent-valley-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Fragrant and refined Pinot Noir featuring wild strawberry and fine-grained tannins.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "Marco Lubiana",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Derwent Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Dr Edge ---
  {
    name: "Dr Edge Tasmania Pinot Noir",
    slug: "dr-edge-tasmania-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Distinctive, stem-inclusive Pinot Noir with crunchy red fruit and savory edge.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Dr Edge",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Tamar Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Dr Edge North Riesling",
    slug: "dr-edge-north-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Textural and vibrant white wine packed with crisp apple, lime blossom, and minerality.",
    alcohol_percentage: 11.5,
    volume_ml: 750,
    producer_name: "Dr Edge",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Tamar Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Place of Changing Winds ---
  {
    name: "Place of Changing Winds High Density Pinot Noir",
    slug: "place-of-changing-winds-high-density-pinot-noir",
    color: "Red",
    closure: "Cork",
    prompt: "Ultra-concentrated, intensely structured Pinot Noir from high-density plantings.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "Place of Changing Winds",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Macedon Ranges"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Place of Changing Winds Syrah No. 2",
    slug: "place-of-changing-winds-syrah-no-2",
    color: "Red",
    closure: "Cork",
    prompt: "Savory cool-climate Syrah featuring black pepper, dark berry, and herbal complexity.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Place of Changing Winds",
    sparkling: false,
    grapes: ["Syrah"],
    regions: ["Macedon Ranges"],
    vintages: [2020, 2021, 2022]
  },

  # --- Mayer Wines ---
  {
    name: "Timo Mayer Close Planted Pinot Noir",
    slug: "timo-mayer-close-planted-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Whole-bunch fermented Yarra Pinot Noir brimming with spice and dark cherry.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Mayer Wines",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Timo Mayer Bloody Hill Chardonnay",
    slug: "timo-mayer-bloody-hill-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Funky, textured Chardonnay boasting stone fruit flavours and bright minerality.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Mayer Wines",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Luke Lambert ---
  {
    name: "Luke Lambert Syrah",
    slug: "luke-lambert-syrah",
    color: "Red",
    closure: "Screw cap",
    prompt: "Artisanal cool-climate Syrah with savory olives, dried herbs, and blue fruit aromas.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "Luke Lambert",
    sparkling: false,
    grapes: ["Syrah"],
    regions: ["Yarra Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Luke Lambert Nebbiolo",
    slug: "luke-lambert-nebbiolo",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic expressions of tar, roses, and cherry supported by firm structure.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Luke Lambert",
    sparkling: false,
    grapes: ["Nebbiolo"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Standish Wine Company ---
  {
    name: "The Standish Shiraz",
    slug: "the-standish-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic, old-vine Barossa Shiraz bursting with concentrated dark fruit and spice.",
    alcohol_percentage: 14.9,
    volume_ml: 750,
    producer_name: "Standish Wine Company",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Standish The Relic Shiraz Viognier",
    slug: "standish-the-relic-shiraz-viognier",
    color: "Red",
    closure: "Cork",
    prompt: "Floral co-fermented Shiraz with silken tannins and expressive berry bouquet.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Standish Wine Company",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Frankland Estate ---
  {
    name: "Frankland Estate Isolation Ridge Riesling",
    slug: "frankland-estate-isolation-ridge-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Organic certified single-vineyard Riesling with lime pith and wet stone purity.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Frankland Estate",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Great Southern"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Frankland Estate Isolation Ridge Shiraz",
    slug: "frankland-estate-isolation-ridge-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Elegant, cool-climate Shiraz displaying white pepper, plums, and fine spice.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Frankland Estate",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Great Southern"],
    vintages: [2019, 2020, 2021]
  },

  # --- Penfolds ---
  {
    name: "Penfolds Grange",
    slug: "penfolds-grange",
    color: "Red",
    closure: "Cork",
    prompt: "Australia's legendary flagship red wine delivering extraordinary power and longevity.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Penfolds",
    sparkling: false,
    grapes: ["Shiraz", "Cabernet Sauvignon"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Penfolds Bin 389 Cabernet Shiraz",
    slug: "penfolds-bin-389-cabernet-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Often referred to as 'Baby Grange', offering dark fruit depth and balanced oak.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Penfolds",
    sparkling: false,
    grapes: ["Cabernet Sauvignon", "Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Henschke ---
  {
    name: "Henschke Hill of Grace",
    slug: "henschke-hill-of-grace",
    color: "Red",
    closure: "Vino-Lok",
    prompt: "Single-vineyard masterpiece crafted from century-old vines with rich complexity.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Henschke",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Eden Valley"],
    vintages: [2016, 2017, 2018]
  },
  {
    name: "Henschke Julius Riesling",
    slug: "henschke-julius-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine Eden Valley Riesling with fragrant orange blossom and intense citrus core.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Henschke",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Eden Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Yalumba ---
  {
    name: "Yalumba The Signature Cabernet Shiraz",
    slug: "yalumba-the-signature-cabernet-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic Australian blend displaying dark chocolate, cassis, and savory oak traits.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Yalumba",
    sparkling: false,
    grapes: ["Cabernet Sauvignon", "Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Yalumba The Virgilius Viognier",
    slug: "yalumba-the-virgilius-viognier",
    color: "White",
    closure: "Screw cap",
    prompt: "Australia's benchmark Viognier offering apricot nectar, white peach, and ginger.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Yalumba",
    sparkling: false,
    grapes: ["Viognier"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Torbreck Vintners ---
  {
    name: "Torbreck RunRig",
    slug: "torbreck-runrig",
    color: "Red",
    closure: "Cork",
    prompt: "Opulent Shiraz touch-infused with Viognier showing power, silkiness, and depth.",
    alcohol_percentage: 15.0,
    volume_ml: 750,
    producer_name: "Torbreck Vintners",
    sparkling: false,
    grapes: ["Shiraz", "Viognier"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Torbreck Woodcutter's Shiraz",
    slug: "torbreck-woodcutters-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Generous and plush Barossa Shiraz packed with dark berry fruit and subtle spice.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Torbreck Vintners",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Grant Burge ---
  {
    name: "Grant Burge Meshach Shiraz",
    slug: "grant-burge-meshach-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Flagship old-vine Shiraz delivering rich blackberry, leather, and vanilla notes.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Grant Burge",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2016, 2017, 2018]
  },
  {
    name: "Grant Burge Holy Trinity Grenache Shiraz Mourvèdre",
    slug: "grant-burge-holy-trinity-grenache-shiraz-mourvedre",
    color: "Red",
    closure: "Screw cap",
    prompt: "Smooth, medium-bodied traditional GSM blend bursting with ripe raspberry fruit.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Grant Burge",
    sparkling: false,
    grapes: ["Grenache", "Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Peter Lehmann Wines ---
  {
    name: "Peter Lehmann Stonewell Shiraz",
    slug: "peter-lehmann-stonewell-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Concentrated and structured flagship Shiraz showing dark fruit, anise, and cedar.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Peter Lehmann Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2016, 2017, 2018]
  },
  {
    name: "Peter Lehmann Wigan Riesling",
    slug: "peter-lehmann-wigan-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Aged museum release Riesling filled with kerosene, toast, and crisp lime notes.",
    alcohol_percentage: 11.5,
    volume_ml: 750,
    producer_name: "Peter Lehmann Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Barossa Valley"],
    vintages: [2015, 2016, 2017]
  },

  # --- Rockford Wines ---
  {
    name: "Rockford Basket Press Shiraz",
    slug: "rockford-basket-press-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Cult classic artisanal Shiraz traditional basket pressed for ultimate balance.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Rockford Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Rockford Alicante Bouchet",
    slug: "rockford-alicante-bouchet",
    color: "Rosé",
    closure: "Screw cap",
    prompt: "Fresh, vibrant, slightly sweet rosé crafted from red-fleshed Alicante grapes.",
    alcohol_percentage: 10.5,
    volume_ml: 750,
    producer_name: "Rockford Wines",
    sparkling: false,
    grapes: ["Semillon"], # Note: unique Alicante fruit, recorded blend base
    regions: ["Barossa Valley"],
    vintages: [2022, 2023]
  },

  # --- Charles Melton Wines ---
  {
    name: "Charles Melton Nine Popes",
    slug: "charles-melton-nine-popes",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic Australian GSM blend delivering rich, velvety red berry, and earth flavors.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Charles Melton Wines",
    sparkling: false,
    grapes: ["Grenache", "Shiraz", "Mourvèdre"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Charles Melton Voice of Angels Shiraz",
    slug: "charles-melton-voice-of-angels-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Single vineyard elegant expression of classic rich Barossa Shiraz.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Charles Melton Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Elderton Wines ---
  {
    name: "Elderton Command Single Vineyard Shiraz",
    slug: "elderton-command-single-vineyard-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "World-renowned full-bodied Shiraz sourced from vines planted in 1894.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Elderton Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Elderton Ashmead Cabernet Sauvignon",
    slug: "elderton-ashmead-cabernet-sauvignon",
    color: "Red",
    closure: "Cork",
    prompt: "Single vineyard Cabernet rich in cassis, menthol, and structured oak tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Elderton Wines",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Chateau Tanunda ---
  {
    name: "Chateau Tanunda 100 Year Old Vines Shiraz",
    slug: "chateau-tanunda-100-year-old-vines-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Deeply concentrated historical wine offering blackberry jam and cocoa flavors.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Chateau Tanunda",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Chateau Tanunda Terroirs Grenache",
    slug: "chateau-tanunda-terroirs-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Bright red fruit forward style with savory herbs and smooth, rounded tannins.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Chateau Tanunda",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- St Hallett ---
  {
    name: "St Hallett Old Block Shiraz",
    slug: "st-hallett-old-block-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Benchmark Barossa Shiraz expressing rich plum, dark fruit, and silky tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "St Hallett",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "St Hallett Faith Shiraz",
    slug: "st-hallett-faith-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Accessible, soft, and vibrant Shiraz filled with ripe cherry and chocolate spice.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "St Hallett",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Jacob's Creek (Orlando Wines) ---
  {
    name: "Jacob's Creek Steingarten Riesling",
    slug: "jacobs-creek-steingarten-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine, intense Riesling with sharp mineral acidity and lime oil aromas.",
    alcohol_percentage: 11.5,
    volume_ml: 750,
    producer_name: "Jacob's Creek (Orlando Wines)",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Jacob's Creek Reserve Shiraz",
    slug: "jacobs-creek-reserve-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic regional Shiraz offering rich blackberry fruit and subtle oak integration.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Jacob's Creek (Orlando Wines)",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Wolf Blass ---
  {
    name: "Wolf Blass Black Label Cabernet Shiraz",
    slug: "wolf-blass-black-label-cabernet-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Multi-award-winning iconic blend known for power, structure, and rich plush fruit.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Wolf Blass",
    sparkling: false,
    grapes: ["Cabernet Sauvignon", "Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Wolf Blass Yellow Label Chardonnay",
    slug: "wolf-blass-yellow-label-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Smooth and creamy white featuring peach flavors integrated with gentle oak.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Wolf Blass",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Barossa Valley"],
    vintages: [2022, 2023]
  },

  # --- Seppeltsfield ---
  {
    name: "Seppeltsfield 100 Year Old Para Vintage Tawny",
    slug: "seppeltsfield-100-year-old-para-vintage-tawny",
    color: "Red",
    closure: "Cork",
    prompt: "Incomparable fortified wine aged 100 years displaying extreme richness and history.",
    alcohol_percentage: 20.0,
    volume_ml: 375,
    producer_name: "Seppeltsfield",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [1920, 1921, 1922]
  },
  {
    name: "Seppeltsfield Barossa Grenache",
    slug: "seppeltsfield-barossa-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Modern, un-oaked style of Grenache brimming with juicy red fruit and spice.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Seppeltsfield",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Two Hands Wines ---
  {
    name: "Two Hands Bella's Garden Shiraz",
    slug: "two-hands-bellas-garden-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Opulent and plush Barossa Shiraz displaying dark fruit, mocha, and fine spice.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Two Hands Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Two Hands Ares Shiraz",
    slug: "two-hands-ares-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Flagship selection representing the absolute pinnacle of Barossa Valley Shiraz.",
    alcohol_percentage: 15.0,
    volume_ml: 750,
    producer_name: "Two Hands Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },

  # --- Turkey Flat ---
  {
    name: "Turkey Flat Shiraz",
    slug: "turkey-flat-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Estate Shiraz from old vines showing elegance, dark plum, and structural length.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Turkey Flat",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Turkey Flat Rosé",
    slug: "turkey-flat-rose",
    color: "Rosé",
    closure: "Screw cap",
    prompt: "Benchmark dry Australian Rosé packed with fresh strawberry and savory spice.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Turkey Flat",
    sparkling: false,
    grapes: ["Rosé blend"],
    regions: ["Barossa Valley"],
    vintages: [2022, 2023]
  },

  # --- Langmeil Winery ---
  {
    name: "Langmeil 1843 Freedom Shiraz",
    slug: "langmeil-1843-freedom-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Crafted from what are believed to be the world's oldest surviving Shiraz vines.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Langmeil Winery",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Langmeil Three Gardens SMG",
    slug: "langmeil-three-gardens-smg",
    color: "Red",
    closure: "Screw cap",
    prompt: "Traditional medium-bodied Rhone blend with lively red fruit and rounded tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Langmeil Winery",
    sparkling: false,
    grapes: ["Shiraz", "Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Kalleske ---
  {
    name: "Kalleske Johann Georg Shiraz",
    slug: "kalleske-johann-georg-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Organic old-vine single-vineyard red featuring intense berry and oak complexity.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Kalleske",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Kalleske Clarry's GSM",
    slug: "kalleske-clarrys-gsm",
    color: "Red",
    closure: "Screw cap",
    prompt: "Fresh, biodynamic red blend packed with juicy raspberry and dark cherry.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Kalleske",
    sparkling: false,
    grapes: ["Grenache", "Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Spinifex Wines ---
  {
    name: "Spinifex Papillon Grenache Shiraz",
    slug: "spinifex-papillon-grenache-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Vibrant, savory light-to-medium red with wild strawberry and floral aromas.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Spinifex Wines",
    sparkling: false,
    grapes: ["Grenache", "Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Spinifex Indigene Shiraz Mataro",
    slug: "spinifex-indigene-shiraz-mataro",
    color: "Red",
    closure: "Cork",
    prompt: "Muscular, complex red showing dark berry fruit, cured meat, and leather traits.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Spinifex Wines",
    sparkling: false,
    grapes: ["Shiraz", "Mourvèdre"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Teusner Wines ---
  {
    name: "Teusner Avatar Grenache Mataro Shiraz",
    slug: "teusner-avatar-grenache-mataro-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Old-vine GMS displaying bright raspberry, red cherry, and Asian spice.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Teusner Wines",
    sparkling: false,
    grapes: ["Grenache", "Mourvèdre", "Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Teusner Albert Shiraz",
    slug: "teusner-albert-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Rich and structured Barossa Shiraz named in honor of ancient local viticulture.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Teusner Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Glaetzer Wines ---
  {
    name: "Glaetzer Amon-Ra Shiraz",
    slug: "glaetzer-amon-ra-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "An iconic, deeply concentrated Barossa Shiraz with dark chocolate and cassis.",
    alcohol_percentage: 15.0,
    volume_ml: 750,
    producer_name: "Glaetzer Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Glaetzer Anaperenna Shiraz Cabernet",
    slug: "glaetzer-anaperenna-shiraz-cabernet",
    color: "Red",
    closure: "Cork",
    prompt: "Seamless blend showing intense dark fruit, licorice, and powerful structure.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Glaetzer Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- d'Arenberg ---
  {
    name: "d'Arenberg The Dead Arm Shiraz",
    slug: "darenberg-the-dead-arm-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Rich and muscular McLaren Vale Shiraz loaded with savory plum and dark spice.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "d'Arenberg",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "d'Arenberg The Hermit Crab Viognier Marsanne",
    slug: "darenberg-the-hermit-crab-viognier-marsanne",
    color: "White",
    closure: "Screw cap",
    prompt: "Aromatic white blend displaying candied ginger, white peach, and stone fruits.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "d'Arenberg",
    sparkling: false,
    grapes: ["Viognier"],
    regions: ["McLaren Vale"],
    vintages: [2021, 2022, 2023]
  },

  # --- Wirra Wirra ---
  {
    name: "Wirra Wirra Church Block",
    slug: "wirra-wirra-church-block",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic Australian blend of Cabernet, Shiraz, and Merlot with rich black fruits.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Wirra Wirra",
    sparkling: false,
    grapes: ["Cabernet Sauvignon", "Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Wirra Wirra RSW Shiraz",
    slug: "wirra-wirra-rsw-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship McLaren Vale Shiraz with dark berry intensity and fine structural tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Wirra Wirra",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2017, 2018, 2019]
  },

  # --- Chapel Hill ---
  {
    name: "Chapel Hill The Vicar Shiraz",
    slug: "chapel-hill-the-vicar-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Sensational flagship red displaying blackberry, dark chocolate, and savory depth.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Chapel Hill",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Chapel Hill McLaren Vale Cabernet Sauvignon",
    slug: "chapel-hill-mclaren-vale-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Varietal Cabernet offering rich blackcurrant, dried mint, and firm tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Chapel Hill",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["McLaren Vale"],
    vintages: [2019, 2020, 2021]
  },

  # --- Coriole ---
  {
    name: "Coriole Lloyd Reserve Shiraz",
    slug: "coriole-lloyd-reserve-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Iconic single-vineyard red showcasing remarkable depth, plum, and earth tones.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Coriole",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2016, 2017, 2018]
  },
  {
    name: "Coriole Sangiovese",
    slug: "coriole-sangiovese",
    color: "Red",
    closure: "Screw cap",
    prompt: "Pioneering Australian Sangiovese boasting savory red cherry and drying tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Coriole",
    sparkling: false,
    grapes: ["Sangiovese"],
    regions: ["McLaren Vale"],
    vintages: [2021, 2022, 2023]
  },

  # --- S.C. Pannell ---
  {
    name: "S.C. Pannell Smart Grenache",
    slug: "sc-pannell-smart-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Ethereal old-vine Grenache with high aromatic floral lift and bright red fruits.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "S.C. Pannell",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["McLaren Vale"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "S.C. Pannell Dead Arm Shiraz",
    slug: "sc-pannell-syrah-touriga",
    color: "Red",
    closure: "Screw cap",
    prompt: "Innovative medium-bodied red displaying dark berries, herbal spice, and soft tannins.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "S.C. Pannell",
    sparkling: false,
    grapes: ["Shiraz", "Tempranillo"],
    regions: ["McLaren Vale"],
    vintages: [2020, 2021, 2022]
  },

  # --- Yangarra Estate Vineyard ---
  {
    name: "Yangarra High Sands Grenache",
    slug: "yangarra-high-sands-grenache",
    color: "Red",
    closure: "Cork",
    prompt: "World-class biodynamic Grenache displaying incredible precision, purity, and depth.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Yangarra Estate Vineyard",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["McLaren Vale"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Yangarra Roux Beauté Roussanne",
    slug: "yangarra-roux-beaute-roussanne",
    color: "White",
    closure: "Cork",
    prompt: "Ceramic egg fermented white wine rich in herbal tea, quince, and waxy texture.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Yangarra Estate Vineyard",
    sparkling: false,
    grapes: ["Roussanne"],
    regions: ["McLaren Vale"],
    vintages: [2020, 2021, 2022]
  },

  # --- Gemtree Wines ---
  {
    name: "Gemtree Bloodstone Shiraz",
    slug: "gemtree-bloodstone-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Organic and biodynamic red wine filled with generous dark chocolate and plum.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Gemtree Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Gemtree Ernest Allan Shiraz",
    slug: "gemtree-ernest-allan-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Premium single-vineyard expression with elegant tannin structure and dark fruit.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Gemtree Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2019, 2020, 2021]
  },

  # --- Kay Brothers ---
  {
    name: "Kay Brothers Block 6 Shiraz",
    slug: "kay-brothers-block-6-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Historic old-vine red wine fermented in open basket presses with rich concentration.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Kay Brothers",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Kay Brothers Griffon's Key Grenache",
    slug: "kay-brothers-griffons-key-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Pure expression of old-vine Grenache with fragrant spice, raspberry, and earth.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Kay Brothers",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["McLaren Vale"],
    vintages: [2019, 2020, 2021]
  },

  # --- Clarendon Hills ---
  {
    name: "Clarendon Hills Astralis Shiraz",
    slug: "clarendon-hills-astralis-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic world-renowned Shiraz delivering massive depth, dark fruit, and savory complexity.",
    alcohol_percentage: 15.0,
    volume_ml: 750,
    producer_name: "Clarendon Hills",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2016, 2017, 2018]
  },
  {
    name: "Clarendon Hills Romas Grenache",
    slug: "clarendon-hills-romas-grenache",
    color: "Red",
    closure: "Cork",
    prompt: "Extremely high-end old-vine Grenache featuring intense minerality and red fruit.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Clarendon Hills",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["McLaren Vale"],
    vintages: [2017, 2018, 2019]
  },

  # --- Ochota Barrels ---
  {
    name: "Ochota Barrels Green Room Grenache",
    slug: "ochota-barrels-green-room-grenache",
    color: "Red",
    closure: "Crownseal",
    prompt: "Light-bodied, natural-style red bursting with campari botanicals and wild berries.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Ochota Barrels",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["McLaren Vale"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Ochota Barrels Where's The Pope Syrah",
    slug: "ochota-barrels-wheres-the-pope-syrah",
    color: "Red",
    closure: "Crownseal",
    prompt: "Vibrant, low-intervention Syrah with lifted violet aromatics and crunchy red plum.",
    alcohol_percentage: 12.8,
    volume_ml: 750,
    producer_name: "Ochota Barrels",
    sparkling: false,
    grapes: ["Syrah"],
    regions: ["Adelaide Hills"],
    vintages: [2021, 2022, 2023]
  },

  # --- Brash Higgins ---
  {
    name: "Brash Higgins NDV Nero d'Avola",
    slug: "brash-higgins-ndv-nero-davola",
    color: "Red",
    closure: "Cork",
    prompt: "Amphora-fermented red displaying wild cherry, leather, and vibrant Mediterranean acidity.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Brash Higgins",
    sparkling: false,
    grapes: ["Nero d'Avola"],
    regions: ["McLaren Vale"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Brash Higgins CBS Cabernet Sauvignon",
    slug: "brash-higgins-cbs-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single-vineyard expression packed with dark fruit, cedar wood, and olive tapenade.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Brash Higgins",
    sparkling: false,
    grapes: ["Shiraz"], # recorded style blend match
    regions: ["McLaren Vale"],
    vintages: [2019, 2020, 2021]
  },

  # --- Hardys ---
  {
    name: "Hardys Eileen Hardy Shiraz",
    slug: "hardys-eileen-hardy-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Flagship luxury red selection showcasing incredible power, spice, and structure.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Hardys",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["McLaren Vale"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Hardys HRB Chardonnay",
    slug: "hardys-hrb-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Multi-regional white blend delivering elegant stone fruit, white peach, and fine oak.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Hardys",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["McLaren Vale"],
    vintages: [2021, 2022, 2023]
  },

  # --- Grosset Wines ---
  {
    name: "Grosset Polish Hill Riesling",
    slug: "grosset-polish-hill-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Australia's benchmark Riesling, intensely mineral, dry, with driving citrus acid.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Grosset Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Clare Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Grosset Gaia Cabernet Blend",
    slug: "grosset-gaia-cabernet-blend",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single vineyard high-altitude blend showcasing blackcurrant, dark plum, and earth.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Grosset Wines",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Clare Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Jim Barry Wines ---
  {
    name: "Jim Barry The Armagh Shiraz",
    slug: "jim-barry-the-armagh-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic single-vineyard red wine with deep richness, dark berries, and savory oak.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Jim Barry Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Clare Valley"],
    vintages: [2016, 2017, 2018]
  },
  {
    name: "Jim Barry The Florita Riesling",
    slug: "jim-barry-the-florita-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Single-vineyard landmark Riesling displaying lime flower, citrus, and slate mineral.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Jim Barry Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Clare Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Kilikanoon Wines ---
  {
    name: "Kilikanoon Oracle Shiraz",
    slug: "kilikanoon-oracle-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Intense, brooding Clare Valley red overflowing with dark fruits and cocoa spice.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Kilikanoon Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Clare Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Kilikanoon Mort's Block Riesling",
    slug: "kilikanoon-morts-block-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Classic Watervale expression showing lemon pith, green apple, and crisp acidity.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Kilikanoon Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Clare Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Taylors Wines (Wakefield) ---
  {
    name: "Taylors St Andrews Shiraz",
    slug: "taylors-st-andrews-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship Clare Valley red boasting dark plum, american oak, and rich length.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Taylors Wines (Wakefield)",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Clare Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Taylors Estate Cabernet Sauvignon",
    slug: "taylors-estate-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Widely awarded red showing classic blackcurrant, dark chocolate, and subtle mint.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Taylors Wines (Wakefield)",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Clare Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Pikes Wines ---
  {
    name: "Pikes Traditionale Riesling",
    slug: "pikes-traditionale-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine white wine packed with fresh lime juice, crisp apple, and vibrant acid.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Pikes Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Clare Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Pikes The E.W.P. Shiraz",
    slug: "pikes-the-ewp-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship reserve Shiraz showcasing deep berry fruits, vanillin oak, and fine structure.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Pikes Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Clare Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Mount Horrocks ---
  {
    name: "Mount Horrocks Cordon Cut Riesling",
    slug: "mount-horrocks-cordon-cut-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Iconic sweet dessert wine with luscious marmalade, apricot, and lively acidity.",
    alcohol_percentage: 11.0,
    volume_ml: 375,
    producer_name: "Mount Horrocks",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Clare Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Mount Horrocks Watervale Riesling",
    slug: "mount-horrocks-watervale-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Organic dry Riesling showcasing exquisite purity, lime zest, and floral lift.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Mount Horrocks",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Clare Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Skillogalee ---
  {
    name: "Skillogalee Trevarrick Riesling",
    slug: "skillogalee-trevarrick-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Single-vineyard reserve Riesling offering floral intensity, lime leaf, and mineral finish.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Skillogalee",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Clare Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Skillogalee Basket Pressed Shiraz",
    slug: "skillogalee-basket-pressed-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Handcrafted estate Shiraz brimming with blackberry, dark plum, and oak spice.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Skillogalee",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Clare Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Pewsey Vale ---
  {
    name: "Pewsey Vale Individual Vineyard Riesling",
    slug: "pewsey-vale-individual-vineyard-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Classic high-altitude Eden Valley Riesling with crushed herbs and intense lime juice.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Pewsey Vale",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Eden Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Pewsey Vale The Contours Riesling",
    slug: "pewsey-vale-the-contours-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Museum release dry Riesling showing secondary notes of toast, lemongrass, and petroleum.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Pewsey Vale",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Eden Valley"],
    vintages: [2016, 2017, 2018]
  },

  # --- Heggies Vineyard ---
  {
    name: "Heggies Vineyard Estate Chardonnay",
    slug: "heggies-vineyard-estate-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Cool-climate high-altitude Chardonnay displaying white peach and subtle toasted oak.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Heggies Vineyard",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Eden Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Heggies Vineyard Estate Viognier",
    slug: "heggies-vineyard-estate-viognier",
    color: "White",
    closure: "Screw cap",
    prompt: "Delicate white wine offering aromatic white flower, ginger spice, and peach skin.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Heggies Vineyard",
    sparkling: false,
    grapes: ["Viognier"],
    regions: ["Eden Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Shaw + Smith ---
  {
    name: "Shaw + Smith Sauvignon Blanc",
    slug: "shaw-smith-sauvignon-blanc",
    color: "White",
    closure: "Screw cap",
    prompt: "Australia's benchmark Sauvignon Blanc with vibrant passionfruit, pink grapefruit, and grass.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Shaw + Smith",
    sparkling: false,
    grapes: ["Sauvignon Blanc"],
    regions: ["Adelaide Hills"],
    vintages: [2022, 2023]
  },
  {
    name: "Shaw + Smith M3 Chardonnay",
    slug: "shaw-smith-m3-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Elegant and sophisticated white showing nectarine, toasted hazelnut, and refined acidity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Shaw + Smith",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Adelaide Hills"],
    vintages: [2020, 2021, 2022]
  },

  # --- Ashton Hills ---
  {
    name: "Ashton Hills Reserve Pinot Noir",
    slug: "ashton-hills-reserve-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Premier Australian Pinot Noir displaying complex forest floor, dark cherry, and fine tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Ashton Hills",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Adelaide Hills"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Ashton Hills Estate Riesling",
    slug: "ashton-hills-estate-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Crisp cool-climate Riesling packed with orange blossom, red apple, and quartz minerality.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Ashton Hills",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Adelaide Hills"],
    vintages: [2021, 2022, 2023]
  },

  # --- The Lane Vineyard ---
  {
    name: "The Lane Gathering Chardonnay",
    slug: "the-lane-gathering-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Single-vineyard white offering intense white peach, grapefruit, and cashew complexity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "The Lane Vineyard",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Adelaide Hills"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "The Lane Block 14 Shiraz",
    slug: "the-lane-block-14-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Cool-climate Adelaide Hills Shiraz with fragrant white pepper and dark blackberry.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "The Lane Vineyard",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Adelaide Hills"],
    vintages: [2019, 2020, 2021]
  },

  # --- Bird in Hand ---
  {
    name: "Bird in Hand Nest Egg Chardonnay",
    slug: "bird-in-hand-nest-egg-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Ultra-premium flagship white displaying pristine citrus, grilled nuts, and French oak depth.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Bird in Hand",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Adelaide Hills"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Bird in Hand Sparkling Pinot Noir",
    slug: "bird-in-hand-sparkling-pinot-noir",
    color: "Rosé",
    closure: "Crownseal",
    prompt: "Wildly popular sparkling rosé brimming with fresh strawberry, floral notes, and delicate bubbles.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Bird in Hand",
    sparkling: true,
    grapes: ["Pinot Noir"],
    regions: ["Adelaide Hills"],
    vintages: [2022, 2023]
  },

  # --- Petaluma ---
  {
    name: "Petaluma Hanlin Hill Riesling",
    slug: "petaluma-hanlin-hill-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Famous single-vineyard Clare Riesling offering concentrated lime juice and floral aromas.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Petaluma",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Adelaide Hills"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Petaluma Piccadilly Valley Chardonnay",
    slug: "petaluma-piccadilly-valley-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Benchmark cool-climate Chardonnay featuring intense melon, citrus, and elegant oak.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Petaluma",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Adelaide Hills"],
    vintages: [2020, 2021, 2022]
  },

  # --- Wynns Coonawarra Estate ---
  {
    name: "Wynns John Riddoch Cabernet Sauvignon",
    slug: "wynns-john-riddoch-cabernet-sauvignon",
    color: "Red",
    closure: "Cork",
    prompt: "Flagship Coonawarra red crafted only in exceptional years with immense structure.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Wynns Coonawarra Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2015, 2016, 2018]
  },
  {
    name: "Wynns Black Label Cabernet Sauvignon",
    slug: "wynns-black-label-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Iconic Australian benchmark Cabernet loaded with dark plum, cassis, and mint notes.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Wynns Coonawarra Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2019, 2020, 2021]
  },

  # --- Katnook Estate ---
  {
    name: "Katnook Odyssey Cabernet Sauvignon",
    slug: "katnook-odyssey-cabernet-sauvignon",
    color: "Red",
    closure: "Cork",
    prompt: "Ultra-premium flagship red showing complex blackcurrant, dark chocolate, and cedar.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Katnook Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2015, 2016, 2017]
  },
  {
    name: "Katnook Founder's Block Shiraz",
    slug: "katnook-founders-block-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Approachable red wine displaying bright dark berries, white pepper, and soft tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Katnook Estate",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Coonawarra"],
    vintages: [2020, 2021, 2022]
  },

  # --- Parker Coonawarra Estate ---
  {
    name: "Parker First Growth Cabernet Sauvignon",
    slug: "parker-first-growth-cabernet-sauvignon",
    color: "Red",
    closure: "Cork",
    prompt: "Prestige Coonawarra Cabernet exhibiting concentrated blackcurrant, graphite, and oak.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Parker Coonawarra Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2016, 2018, 2019]
  },
  {
    name: "Parker Terra Rossa Cabernet Sauvignon",
    slug: "parker-terra-rossa-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic regional expression with cassis, dark plum, mint, and fine cedar tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Parker Coonawarra Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2019, 2020, 2021]
  },

  # --- Balnaves of Coonawarra ---
  {
    name: "Balnaves The Tally Cabernet Sauvignon",
    slug: "balnaves-the-tally-cabernet-sauvignon",
    color: "Red",
    closure: "Cork",
    prompt: "Flagship release showcasing ultimate structure, rich cassis, and long-term aging power.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Balnaves of Coonawarra",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2016, 2017, 2018]
  },
  {
    name: "Balnaves Coonawarra Cabernet Merlot",
    slug: "balnaves-coonawarra-cabernet-merlot",
    color: "Red",
    closure: "Screw cap",
    prompt: "Seamless red blend brimming with blackberry, plum, dark chocolate, and leafy herbs.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Balnaves of Coonawarra",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2019, 2020, 2021]
  },

  # --- Leconfield ---
  {
    name: "Leconfield Sydney Cabernet Sauvignon",
    slug: "leconfield-sydney-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Benchmark terra rossa red delivering ripe blackcurrant, eucalypt, and French oak depth.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Leconfield",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coonawarra"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Leconfield Coonawarra Shiraz",
    slug: "leconfield-coonawarra-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Plush and vibrant red displaying rich blackberry, spice, and soft velvety tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Leconfield",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Coonawarra"],
    vintages: [2019, 2020, 2021]
  },

  # --- Cullen Wines ---
  {
    name: "Cullen Diana Madeline",
    slug: "cullen-diana-madeline",
    color: "Red",
    closure: "Cork",
    prompt: "World-famous biodynamic Cabernet blend displaying supreme elegance, plum, and cedar.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Cullen Wines",
    sparkling: false,
    grapes: ["Cabernet Sauvignon", "Sauvignon Blanc"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Cullen Kevin John Chardonnay",
    slug: "cullen-kevin-john-chardonnay",
    color: "White",
    closure: "Cork",
    prompt: "Iconic biodynamic Chardonnay with driving lemon curd, orange blossom, and savory oak.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Cullen Wines",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2019, 2020, 2021]
  },

  # --- Vasse Felix ---
  {
    name: "Vasse Felix Tom Cullity Cabernet Malbec",
    slug: "vasse-felix-tom-cullity-cabernet-malbec",
    color: "Red",
    closure: "Cork",
    prompt: "Flagship Margaret River red showing extraordinary complexity, dark fruit, and graphite.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Vasse Felix",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Vasse Felix Heytesbury Chardonnay",
    slug: "vasse-felix-heytesbury-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Prestige Australian Chardonnay featuring flinty reduction, wild yeast, and lemon zest.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Vasse Felix",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2020, 2021, 2022]
  },

  # --- Leeuwin Estate ---
  {
    name: "Leeuwin Estate Art Series Chardonnay",
    slug: "leeuwin-estate-art-series-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Global benchmark Chardonnay with immense power, white peach, pear, and toasted cashew.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Leeuwin Estate",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Leeuwin Estate Art Series Cabernet Sauvignon",
    slug: "leeuwin-estate-art-series-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Sophisticated red showcasing cassis, black olive, structured tannins, and cedar.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Leeuwin Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2017, 2018, 2019]
  },

  # --- Moss Wood ---
  {
    name: "Moss Wood Wilyabrup Cabernet Sauvignon",
    slug: "moss-wood-wilyabrup-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Iconic cellaring red wine filled with violet aromatics, mulberry, and fine tannin.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Moss Wood",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Moss Wood Ribbon Vale Semillon",
    slug: "moss-wood-ribbon-vale-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Aromatic white displaying crisp green apple, fig, lemon pith, and herbal notes.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Moss Wood",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Margaret River"],
    vintages: [2021, 2022, 2023]
  },

  # --- Voyager Estate ---
  {
    name: "Voyager Estate MJW Cabernet Sauvignon",
    slug: "voyager-estate-mjw-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship single-block organic Cabernet delivering dark plum, cassis, and fine oak.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Voyager Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2017, 2018, 2020]
  },
  {
    name: "Voyager Estate Broadvale Block 6 Chardonnay",
    slug: "voyager-estate-broadvale-block-6-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Certified organic Chardonnay offering bright citrus, flint, and creamy texture.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Voyager Estate",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2020, 2021, 2022]
  },

  # --- Woodlands ---
  {
    name: "Woodlands Benjamin Cabernet Sauvignon",
    slug: "woodlands-benjamin-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Intense dry-farmed Cabernet boasting dark berries, violet perfume, and fine oak.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Woodlands",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Woodlands Margaret Reserve Cabernet Merlot",
    slug: "woodlands-margaret-reserve-cabernet-merlot",
    color: "Red",
    closure: "Screw cap",
    prompt: "Complex Bordeaux-style blend brimming with dark plum, bay leaf, and silky tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Woodlands",
    sparkling: false,
    grapes: ["Cabernet Sauvignon", "Merlot"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },

  # --- Xanadu Wines ---
  {
    name: "Xanadu Reserve Cabernet Sauvignon",
    slug: "xanadu-reserve-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Trophy-winning Cabernet delivering blackcurrant intensity, graphite, and structured oak.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Xanadu Wines",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Xanadu Reserve Chardonnay",
    slug: "xanadu-reserve-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "High-end Chardonnay displaying lemon blossom, white nectarine, and mineral drive.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Xanadu Wines",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2020, 2021, 2022]
  },

  # --- Fraser Gallop Estate ---
  {
    name: "Fraser Gallop Parterre Cabernet Sauvignon",
    slug: "fraser-gallop-parterre-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Elegant, cool-styled Cabernet featuring cassis, cedar wood, and fine savory tannin.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Fraser Gallop Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Fraser Gallop Parterre Chardonnay",
    slug: "fraser-gallop-parterre-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Refined white wine brimming with citrus fruit, delicate oak, and flinty complexity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Fraser Gallop Estate",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2021, 2022, 2023]
  },

  # --- Pierro ---
  {
    name: "Pierro Chardonnay",
    slug: "pierro-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Pioneering Margaret River Chardonnay delivering intense hazelnut, peach, and stone fruit.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Pierro",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Pierro LTC Semillon Sauvignon Blanc",
    slug: "pierro-ltc-semillon-sauvignon-blanc",
    color: "White",
    closure: "Screw cap",
    prompt: "A touch of Chardonnay added (LTC) creating a silky, textured, citrus-driven white blend.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Pierro",
    sparkling: false,
    grapes: ["Semillon", "Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2021, 2022, 2023]
  },

  # --- Cape Mentelle ---
  {
    name: "Cape Mentelle Cabernet Sauvignon",
    slug: "cape-mentelle-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Historic Margaret River red displaying rich cassis, bay leaf, and structural depth.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Cape Mentelle",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Cape Mentelle Sauvignon Blanc Semillon",
    slug: "cape-mentelle-sauvignon-blanc-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Benchmark Margaret River white blend packed with lime zest, herbs, and passionfruit.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Cape Mentelle",
    sparkling: false,
    grapes: ["Sauvignon Blanc", "Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2021, 2022, 2023]
  },

  # --- Howard Park ---
  {
    name: "Howard Park Abercrombie Cabernet Sauvignon",
    slug: "howard-park-abercrombie-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Prestige Cabernet showcasing dense dark berry fruit, sweet spice, and fine oak.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Howard Park",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River", "Great Southern"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Howard Park Mount Barker Riesling",
    slug: "howard-park-mount-barker-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine dry Riesling brimming with citrus pith, green apple, and wet stone acid.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Howard Park",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Great Southern"],
    vintages: [2021, 2022, 2023]
  },

  # --- Plantagenet Wines ---
  {
    name: "Plantagenet Juxtaposition Shiraz",
    slug: "plantagenet-juxtaposition-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Cool-climate red wine loaded with black pepper, plum, and vibrant structural acid.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Plantagenet Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Great Southern"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Plantagenet Wyjup Collection Riesling",
    slug: "plantagenet-wyjup-collection-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Single vineyard estate white wine featuring intense lime, orange blossom, and mineral core.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Plantagenet Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Great Southern"],
    vintages: [2021, 2022, 2023]
  },

  # --- Domaine Naturaliste ---
  {
    name: "Domaine Naturaliste Reusaste Cabernet Sauvignon",
    slug: "domaine-naturaliste-reusaste-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single-vineyard flagship red displaying blackcurrant, graphite, and silky tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Domaine Naturaliste",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Margaret River"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Domaine Naturaliste Artus Chardonnay",
    slug: "domaine-naturaliste-artus-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Opulent and textured white featuring stone fruit, lemon curd, and wild yeast complexity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Domaine Naturaliste",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Margaret River"],
    vintages: [2020, 2021, 2022]
  },

  # --- Giaconda ---
  {
    name: "Giaconda Estate Vineyard Chardonnay",
    slug: "giaconda-estate-vineyard-chardonnay",
    color: "White",
    closure: "Cork",
    prompt: "World-famous cult Australian Chardonnay with intense mealiness, matchstick, and fruit power.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Giaconda",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Beechworth"],
    vintages: [2018, 2019, 2021]
  },
  {
    name: "Giaconda Estate Vineyard Shiraz",
    slug: "giaconda-estate-vineyard-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Savory cool-climate Shiraz displaying tapenade, dark fruits, spice, and mineral complexity.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Giaconda",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Beechworth"],
    vintages: [2017, 2018, 2019]
  },

  # --- Yering Station ---
  {
    name: "Yering Station Reserve Chardonnay",
    slug: "yering-station-reserve-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Flagship Yarra Chardonnay showcasing crisp grapefruit, stone fruit, and oak complexity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Yering Station",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Yering Station Reserve Pinot Noir",
    slug: "yering-station-reserve-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Refined, complex Pinot Noir packed with dark cherry, spice, and silky structural length.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Yering Station",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Mount Mary ---
  {
    name: "Mount Mary Quintet",
    slug: "mount-mary-quintet",
    color: "Red",
    closure: "Cork",
    prompt: "Legendary Bordeaux-style blend known for ultra-elegance, violet, cassis, and structural length.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Mount Mary",
    sparkling: false,
    grapes: ["Cabernet Sauvignon", "Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Mount Mary Chardonnay",
    slug: "mount-mary-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine cool-climate Chardonnay featuring lemon blossom, pear, and tight mineral finish.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Mount Mary",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Yarra Yering ---
  {
    name: "Yarra Yering Dry Red No. 1",
    slug: "yarra-yering-dry-red-no-1",
    color: "Red",
    closure: "Screw cap",
    prompt: "Iconic Cabernet blend delivering perfume, cassis, fine structure, and decades of potential.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Yarra Yering",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Yarra Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Yarra Yering Dry Red No. 2",
    slug: "yarra-yering-dry-red-no-2",
    color: "Red",
    closure: "Screw cap",
    prompt: "Shiraz-dominant blend with aromatic lift of Viognier, fragrant plum, and spice.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Yarra Yering",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Yarra Valley"],
    vintages: [2017, 2018, 2019]
  },

  # --- De Bortoli ---
  {
    name: "De Bortoli Noble One Botrytis Semillon",
    slug: "de-bortoli-noble-one-botrytis-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "World's most awarded dessert wine overflowing with kumquat, honey, apricot, and citrus acid.",
    alcohol_percentage: 10.5,
    volume_ml: 375,
    producer_name: "De Bortoli",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Yarra Valley", "Riverina"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "De Bortoli Esteem Pinot Noir",
    slug: "de-bortoli-esteem-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Premium Yarra Valley Pinot Noir displaying savory forest floor and dark cherry.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "De Bortoli",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley", "Riverina"],
    vintages: [2020, 2021, 2022]
  },

  # --- Coldstream Hills ---
  {
    name: "Coldstream Hills Reserve Chardonnay",
    slug: "coldstream-hills-reserve-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Sophisticated Yarra white offering citrus rind, white peach, and subtle French oak.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Coldstream Hills",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Coldstream Hills Reserve Pinot Noir",
    slug: "coldstream-hills-reserve-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single vineyard reserve red with intense dark cherry, spice, and velvety finish.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Coldstream Hills",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Oakridge Wines ---
  {
    name: "Oakridge 864 Drive Block Chardonnay",
    slug: "oakridge-864-drive-block-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Single-block benchmark Chardonnay showing extreme mineral drive, citrus, and flint.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "Oakridge Wines",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Oakridge Original Vineyard Pinot Noir",
    slug: "oakridge-original-vineyard-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Detailed red wine offering red plum, dried herb botanicals, and delicate tannin structure.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Oakridge Wines",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Giant Steps ---
  {
    name: "Giant Steps Applejack Vineyard Pinot Noir",
    slug: "giant-steps-applejack-vineyard-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Highly acclaimed single-vineyard red featuring perfumed spice, cherry, and structured length.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Giant Steps",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Giant Steps Sexton Vineyard Chardonnay",
    slug: "giant-steps-sexton-vineyard-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine single-vineyard white displaying white peach, lemon, and flinty complexity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Giant Steps",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- TarraWarra Estate ---
  {
    name: "TarraWarra Reserve Chardonnay",
    slug: "tarrawarra-reserve-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Estate-grown white boasting intense citrus, stone fruit, and creamy, textured length.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "TarraWarra Estate",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "TarraWarra MDB Pinot Noir",
    slug: "tarrawarra-mdb-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship Pinot Noir crafted from selected vineyard blocks displaying rich savory plum.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "TarraWarra Estate",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Mac Forbes ---
  {
    name: "Mac Forbes Woori Yallock Pinot Noir",
    slug: "mac-forbes-woori-yallock-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Sub-regional precision Pinot Noir filled with crunchy red fruit, soil notes, and energy.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Mac Forbes",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Mac Forbes RS5 Riesling",
    slug: "mac-forbes-rs5-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Off-dry expression of Riesling showcasing balanced residual sugar and bright lime acid.",
    alcohol_percentage: 10.5,
    volume_ml: 750,
    producer_name: "Mac Forbes",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Yarra Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Tahbilk ---
  {
    name: "Tahbilk 1860 Vines Shiraz",
    slug: "tahbilk-1860-vines-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Rare historical red crafted from un-grafted pre-phylloxera vines planted in 1860.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Tahbilk",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Nagambie Lakes"],
    vintages: [2015, 2016, 2017]
  },
  {
    name: "Tahbilk Museum Release Marsanne",
    slug: "tahbilk-museum-release-marsanne",
    color: "White",
    closure: "Screw cap",
    prompt: "Iconic aged white wine featuring complex honeysuckle, toast, marmalade, and citrus.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Tahbilk",
    sparkling: false,
    grapes: ["Marsanne"],
    regions: ["Nagambie Lakes"],
    vintages: [2015, 2016, 2017]
  },

  # --- Mitchelton ---
  {
    name: "Mitchelton Black Cluster Shiraz",
    slug: "mitchelton-black-cluster-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship estate red displaying blackberry, dark cocoa, spice, and supple tannins.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Mitchelton",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Nagambie Lakes"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Mitchelton Airstream Marsanne",
    slug: "mitchelton-airstream-marsanne",
    color: "White",
    closure: "Screw cap",
    prompt: "Fresh white displaying white peach, honeysuckle aromas, and crisp citrus finish.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Mitchelton",
    sparkling: false,
    grapes: ["Marsanne"],
    regions: ["Nagambie Lakes"],
    vintages: [2021, 2022, 2023]
  },

  # --- Jasper Hill ---
  {
    name: "Jasper Hill Georgia's Paddock Shiraz",
    slug: "jasper-hill-georgias-paddock-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic dry-farmed Heathcote Shiraz packed with brooding black fruit and ironstone.",
    alcohol_percentage: 15.0,
    volume_ml: 750,
    producer_name: "Jasper Hill",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Heathcote"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Jasper Hill Emily's Paddock Shiraz Cabernet",
    slug: "jasper-hill-emilys-paddock-shiraz-cabernet",
    color: "Red",
    closure: "Cork",
    prompt: "Powerfully structured red blend delivering aniseed, blackcurrant, and savory mineral.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Jasper Hill",
    sparkling: false,
    grapes: ["Shiraz", "Cabernet Sauvignon"],
    regions: ["Heathcote"],
    vintages: [2018, 2019, 2020]
  },

  # --- Brown Brothers ---
  {
    name: "Brown Brothers Patricia Shiraz",
    slug: "brown-brothers-patricia-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship reserve red showcasing dark plum, spicy oak, and exceptional cellar potential.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Brown Brothers",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["King Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Brown Brothers King Valley Prosecco",
    slug: "brown-brothers-king-valley-prosecco",
    color: "White",
    closure: "Crownseal",
    prompt: "Vibrant sparkling white brimming with crisp green apple, citrus, and lively bubbles.",
    alcohol_percentage: 11.5,
    volume_ml: 750,
    producer_name: "Brown Brothers",
    sparkling: true,
    grapes: ["Prosecco (Glera)"],
    regions: ["King Valley"],
    vintages: [2022, 2023]
  },

  # --- Campbells Wines ---
  {
    name: "Campbells Merchant Prince Rare Rutherglen Muscat",
    slug: "campbells-merchant-prince-rare-rutherglen-muscat",
    color: "Red",
    closure: "Cork",
    prompt: "World-class fortified dessert wine boasting raisin, fruitcake, mocha, and incredible intensity.",
    alcohol_percentage: 18.0,
    volume_ml: 375,
    producer_name: "Campbells Wines",
    sparkling: false,
    grapes: ["Muscat"],
    regions: ["Rutherglen"],
    vintages: [2010, 2015, 2020]
  },
  {
    name: "Campbells Barkly Durif",
    slug: "campbells-barkly-durif",
    color: "Red",
    closure: "Screw cap",
    prompt: "Inky, full-bodied red offering dark chocolate, blackberry, and powerful tannins.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Campbells Wines",
    sparkling: false,
    grapes: ["Durif"],
    regions: ["Rutherglen"],
    vintages: [2018, 2019, 2020]
  },

  # --- All Saints Estate ---
  {
    name: "All Saints Rare Rutherglen Muscat",
    slug: "all-saints-rare-rutherglen-muscat",
    color: "Red",
    closure: "Cork",
    prompt: "Complex and viscous fortified wine displaying dark toffee, cold tea, and dried fruit.",
    alcohol_percentage: 18.0,
    volume_ml: 375,
    producer_name: "All Saints Estate",
    sparkling: false,
    grapes: ["Muscat"],
    regions: ["Rutherglen"],
    vintages: [2012, 2016, 2020]
  },
  {
    name: "All Saints Family Reserve Durif",
    slug: "all-saints-family-reserve-durif",
    color: "Red",
    closure: "Screw cap",
    prompt: "Rich regional red delivering intense dark plum, espresso, and firm drying tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "All Saints Estate",
    sparkling: false,
    grapes: ["Durif"],
    regions: ["Rutherglen"],
    vintages: [2018, 2019, 2020]
  },

  # --- Stanton & Killeen ---
  {
    name: "Stanton & Killeen Classic Rutherglen Muscat",
    slug: "stanton-killeen-classic-rutherglen-muscat",
    color: "Red",
    closure: "Screw cap",
    prompt: "Rich fortified wine loaded with butterscotch, fruitcake, and honeyed complexity.",
    alcohol_percentage: 18.0,
    volume_ml: 375,
    producer_name: "Stanton & Killeen",
    sparkling: false,
    grapes: ["Muscat"],
    regions: ["Rutherglen"],
    vintages: [2015, 2018, 2021]
  },
  {
    name: "Stanton & Killeen The Moodemere Durif",
    slug: "stanton-killeen-the-moodemere-durif",
    color: "Red",
    closure: "Screw cap",
    prompt: "Powerful Rutherglen red displaying rich mulberry, licorice, and bold structural tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Stanton & Killeen",
    sparkling: false,
    grapes: ["Durif"],
    regions: ["Rutherglen"],
    vintages: [2019, 2020, 2021]
  },

  # --- Bindi Wines ---
  {
    name: "Bindi Block 5 Pinot Noir",
    slug: "bindi-block-5-pinot-noir",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic Macedon Pinot Noir displaying superb purity, spice, wild strawberry, and earth.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Bindi Wines",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Macedon Ranges"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Bindi Quartz Chardonnay",
    slug: "bindi-quartz-chardonnay",
    color: "White",
    closure: "Cork",
    prompt: "High-altitude white wine with intense mineral drive, white flower aromas, and citrus acid.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Bindi Wines",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Macedon Ranges"],
    vintages: [2019, 2020, 2021]
  },

  # --- Paringa Estate ---
  {
    name: "Paringa Estate The Paringa Pinot Noir",
    slug: "paringa-estate-the-paringa-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship Mornington red offering intense dark cherry, spice, and velvet structure.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Paringa Estate",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Paringa Estate The Paringa Shiraz",
    slug: "paringa-estate-the-paringa-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Award-winning cool-climate Shiraz displaying cracked pepper, violet, and blackberry.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Paringa Estate",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Mornington Peninsula"],
    vintages: [2018, 2019, 2020]
  },

  # --- Ten Minutes by Tractor ---
  {
    name: "Ten Minutes by Tractor Judd Pinot Noir",
    slug: "ten-minutes-by-tractor-judd-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single-vineyard expression with red cherry, violet aromatics, and fine mineral acidity.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Ten Minutes by Tractor",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Ten Minutes by Tractor Wallis Chardonnay",
    slug: "ten-minutes-by-tractor-wallis-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Refined single-vineyard white featuring citrus peel, matchstick, and delicate oak.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Ten Minutes by Tractor",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },

  # --- Kooyong ---
  {
    name: "Kooyong Meres Pinot Noir",
    slug: "kooyong-meres-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single vineyard red displaying savory dried herbs, wild red berries, and fine tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Kooyong",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Kooyong Farrago Chardonnay",
    slug: "kooyong-farrago-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Single vineyard white with striking lemon curd, flinty minerality, and oak frame.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Kooyong",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },

  # --- Moorooduc Estate ---
  {
    name: "Moorooduc Estate The Moorooduc Pinot Noir",
    slug: "moorooduc-estate-the-moorooduc-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Wild-fermented red displaying complex savory earth, dark cherry, and fine tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Moorooduc Estate",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Moorooduc Estate The Moorooduc Chardonnay",
    slug: "moorooduc-estate-the-moorooduc-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Textural, wild-fermented white offering white peach, lemon, and subtle oak spice.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Moorooduc Estate",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },

  # --- Main Ridge Estate ---
  {
    name: "Main Ridge Estate Half Acre Pinot Noir",
    slug: "main-ridge-estate-half-acre-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Historic Mornington single block red displaying high floral lift and pure red fruits.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "Main Ridge Estate",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Main Ridge Estate Estate Chardonnay",
    slug: "main-ridge-estate-estate-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Cool-climate white with driving acidity, citrus pith, and almond meal richness.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Main Ridge Estate",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Mornington Peninsula"],
    vintages: [2019, 2020, 2021]
  },

  # --- Tyrrell's Wines ---
  {
    name: "Tyrrell's Vat 1 Semillon",
    slug: "tyrrells-vat-1-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Australia's premier Semillon, releasing pristine citrus acidity that ages into honeyed toast.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Tyrrell's Wines",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2015, 2016, 2017]
  },
  {
    name: "Tyrrell's Vat 9 Shiraz",
    slug: "tyrrells-vat-9-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Iconic Hunter red sourced from historical blocks showcasing savory plum and leather.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Tyrrell's Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2017, 2018, 2019]
  },

  # --- Brokenwood Wines ---
  {
    name: "Brokenwood Graveyard Vineyard Shiraz",
    slug: "brokenwood-graveyard-vineyard-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Benchmark Hunter Valley red filled with red berry, leather, and fine long tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Brokenwood Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Brokenwood ILR Reserve Semillon",
    slug: "brokenwood-ilr-reserve-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Aged reserve white wine showing complex toast, lemon curd, and vibrant acidity.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Brokenwood Wines",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2015, 2016, 2017]
  },

  # --- Mount Pleasant (McWilliam's) ---
  {
    name: "Mount Pleasant Maurice O'Shea Shiraz",
    slug: "mount-pleasant-maurice-oshea-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Prestige historic Hunter Valley red with immense depth, savory complexity, and elegance.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Mount Pleasant (McWilliam's)",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Mount Pleasant Lovedale Semillon",
    slug: "mount-pleasant-lovedale-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Single vineyard white showcasing lime zest, herb notes, and fantastic aging grace.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Mount Pleasant (McWilliam's)",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2014, 2015, 2017]
  },

  # --- Tulloch ---
  {
    name: "Tulloch Hector Shiraz",
    slug: "tulloch-hector-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship old-vine Hunter Shiraz with dark cherry fruit, earth, and supple tannins.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Tulloch",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Tulloch E.M. Limited Release Semillon",
    slug: "tulloch-em-limited-release-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine white wine displaying crisp lemon, lemongrass, and vibrant mineral acid.",
    alcohol_percentage: 11.5,
    volume_ml: 750,
    producer_name: "Tulloch",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Lake's Folly ---
  {
    name: "Lake's Folly Cabernets",
    slug: "lakes-folly-cabernets",
    color: "Red",
    closure: "Cork",
    prompt: "Australia's original boutique red wine blend displaying cedar, cassis, and finesse.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Lake's Folly",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Hunter Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Lake's Folly Chardonnay",
    slug: "lakes-folly-chardonnay",
    color: "White",
    closure: "Cork",
    prompt: "Iconic barrel-fermented Chardonnay featuring stone fruit, cashew, and vibrant acidity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Lake's Folly",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Hunter Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Clonakilla ---
  {
    name: "Clonakilla Shiraz Viognier",
    slug: "clonakilla-shiraz-viognier",
    color: "Red",
    closure: "Screw cap",
    prompt: "Benchmark Canberra red displaying floral lift, cracked white pepper, and red plum.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Clonakilla",
    sparkling: false,
    grapes: ["Shiraz", "Viognier"],
    regions: ["Canberra District"],
    vintages: [2019, 2021, 2022]
  },
  {
    name: "Clonakilla Canberra District Riesling",
    slug: "clonakilla-canberra-district-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Cool-climate white wine packed with lime zest, green apple, and refined minerality.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Clonakilla",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Canberra District"],
    vintages: [2021, 2022, 2023]
  },

  # --- Mount Majura Vineyard ---
  {
    name: "Mount Majura Tempranillo",
    slug: "mount-majura-tempranillo",
    color: "Red",
    closure: "Screw cap",
    prompt: "Australia's benchmark Tempranillo bursting with dark cherry, spice, and savory tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Mount Majura Vineyard",
    sparkling: false,
    grapes: ["Tempranillo"],
    regions: ["Canberra District"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Mount Majura TSG",
    slug: "mount-majura-tsg",
    color: "Red",
    closure: "Screw cap",
    prompt: "Vibrant blend of Tempranillo, Shiraz, and Graciano packed with red fruit and spice.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Mount Majura Vineyard",
    sparkling: false,
    grapes: ["Tempranillo", "Shiraz"],
    regions: ["Canberra District"],
    vintages: [2020, 2021, 2022]
  },

  # --- Freycinet Vineyard ---
  {
    name: "Freycinet Pinot Noir",
    slug: "freycinet-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic Tasmanian red offering ripe plum, dark cherry, spice, and structured oak.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Freycinet Vineyard",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["East Coast Tasmania"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Freycinet Chardonnay",
    slug: "freycinet-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Intense cool-climate Chardonnay featuring melon, grapefruit, and toasted hazelnut.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Freycinet Vineyard",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["East Coast Tasmania"],
    vintages: [2020, 2021, 2022]
  },

  # --- Josef Chromy Wines ---
  {
    name: "Josef Chromy ZDar Pinot Noir",
    slug: "josef-chromy-zdar-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship Tasmanian Pinot Noir showcasing deep red fruit, spice, and velvet length.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Josef Chromy Wines",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Tamar Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Josef Chromy NV Sparkling Brut",
    slug: "josef-chromy-nv-sparkling-brut",
    color: "White",
    closure: "Crownseal",
    prompt: "Traditional method Tasmanian sparkling with green apple, brioche, and fine bead.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Josef Chromy Wines",
    sparkling: true,
    grapes: ["Chardonnay", "Pinot Noir"],
    regions: ["Tamar Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Bay of Fires ---
  {
    name: "Bay of Fires Pinot Noir",
    slug: "bay-of-fires-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Detailed Tasmanian Pinot Noir brimming with dark plum, spice, and subtle oak notes.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Bay of Fires",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["North East Tasmania"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Bay of Fires Chardonnay",
    slug: "bay-of-fires-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Cool-climate white with vibrant lemon curd, white peach, and stony minerality.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Bay of Fires",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["North East Tasmania"],
    vintages: [2020, 2021, 2022]
  },

  # --- Tolpuddle Vineyard ---
  {
    name: "Tolpuddle Vineyard Pinot Noir",
    slug: "tolpuddle-vineyard-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "World-class Coal River Pinot Noir packed with dark cherry, spice, and silky tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Tolpuddle Vineyard",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Coal River Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Tolpuddle Vineyard Chardonnay",
    slug: "tolpuddle-vineyard-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Benchmark Australian Chardonnay featuring flint, bright citrus, and long persistent finish.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Tolpuddle Vineyard",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Coal River Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Stefano Lubiana ---
  {
    name: "Stefano Lubiana Estate Pinot Noir",
    slug: "stefano-lubiana-estate-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Biodynamic red wine displaying perfumed red berries, savory spice, and fine structure.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Stefano Lubiana",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Derwent Valley"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Stefano Lubiana Grande Vintage Sparkling",
    slug: "stefano-lubiana-grande-vintage-sparkling",
    color: "White",
    closure: "Crownseal",
    prompt: "Prestige vintage traditional method sparkling featuring extended lees aging and toast.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Stefano Lubiana",
    sparkling: true,
    grapes: ["Chardonnay", "Pinot Noir"],
    regions: ["Derwent Valley"],
    vintages: [2015, 2016, 2017]
  },

  # --- Domaine A ---
  {
    name: "Domaine A Cabernet Sauvignon",
    slug: "domaine-a-cabernet-sauvignon",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic cool-climate Cabernet with long barrel aging, cassis, graphite, and cedar.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Domaine A",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Coal River Valley"],
    vintages: [2011, 2012, 2013]
  },
  {
    name: "Domaine A Pinot Noir",
    slug: "domaine-a-pinot-noir",
    color: "Red",
    closure: "Cork",
    prompt: "Sophisticated aged Tasmanian Pinot Noir displaying truffle, forest floor, and cherry.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Domaine A",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Coal River Valley"],
    vintages: [2015, 2016, 2017]
  },

  # --- Pooley Wines ---
  {
    name: "Pooley Jack Denis Pooley Riesling",
    slug: "pooley-jack-denis-pooley-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Single vineyard reserve Riesling with precise lime acid and striking mineral purity.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Pooley Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Coal River Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Pooley Cooinda Vale Pinot Noir",
    slug: "pooley-cooinda-vale-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Aromatic single vineyard red overflowing with black cherry, spice, and silk tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Pooley Wines",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Coal River Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Best's Wines ---
  {
    name: "Best's Thomson Family Shiraz",
    slug: "bests-thomson-family-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Rare flagship red from 1868 plantings showing dark berry, spice, and longevity.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Best's Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Great Western"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Best's Great Western Riesling",
    slug: "bests-great-western-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Classic Victorian dry Riesling featuring green apple, lime zest, and mineral acidity.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Best's Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Great Western"],
    vintages: [2021, 2022, 2023]
  },

  # --- Seppelt ---
  {
    name: "Seppelt St Peters Shiraz",
    slug: "seppelt-st-peters-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Prestige Grampians Shiraz showcasing dark plum, cracked pepper, and structured oak.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Seppelt",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Grampians"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Seppelt Original Sparkling Shiraz",
    slug: "seppelt-original-sparkling-shiraz",
    color: "Red",
    closure: "Crownseal",
    prompt: "Uniquely Australian red sparkling packed with dark berry fruit, spice, and fine bubbles.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Seppelt",
    sparkling: true,
    grapes: ["Sparkling Shiraz"],
    regions: ["Grampians"],
    vintages: [2019, 2020, 2021]
  },

  # --- Craiglee ---
  {
    name: "Craiglee Sunbury Shiraz",
    slug: "craiglee-sunbury-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Benchmark cool-climate Shiraz displaying white pepper, savory plum, and elegance.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Craiglee",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Sunbury"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Craiglee Sunbury Chardonnay",
    slug: "craiglee-sunbury-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Refined Victorian white with citrus peel, delicate toast, and bright driving acidity.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Craiglee",
    sparkling: false,
    grapes: ["Shiraz"], # default grape matching set
    regions: ["Sunbury"],
    vintages: [2020, 2021, 2022]
  },

  # --- Bannockburn Vineyards ---
  {
    name: "Bannockburn Serrena Pinot Noir",
    slug: "bannockburn-serrena-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Savory, complex Geelong Pinot Noir packed with dark cherry, spice, and forest floor.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Bannockburn Vineyards",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Geelong"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Bannockburn S.R.H. Chardonnay",
    slug: "bannockburn-srh-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Flagship white wine from old vines displaying rich mealiness, citrus, and flint.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Bannockburn Vineyards",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Geelong"],
    vintages: [2019, 2020, 2021]
  },

  # --- Scotchmans Hill ---
  {
    name: "Scotchmans Hill Estate Pinot Noir",
    slug: "scotchmans-hill-estate-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Bellarine Peninsula red wine brimming with ripe dark fruits, spice, and velvety tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Scotchmans Hill",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Geelong"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Scotchmans Hill Estate Chardonnay",
    slug: "scotchmans-hill-estate-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Maritime cool-climate Chardonnay with white peach, melon, and cashew oak depth.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Scotchmans Hill",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Geelong"],
    vintages: [2020, 2021, 2022]
  },

  # --- Punt Road Wines ---
  {
    name: "Punt Road Estate Pinot Noir",
    slug: "punt-road-estate-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Fresh and vibrant Yarra red featuring bright cherry, subtle spice, and fine tannins.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Punt Road Wines",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Yarra Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Punt Road Estate Chardonnay",
    slug: "punt-road-estate-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Crisp cool-climate white showing white stone fruit, lemon curd, and driving acidity.",
    alcohol_percentage: 12.8,
    volume_ml: 750,
    producer_name: "Punt Road Wines",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Yarra Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- De Iuliis ---
  {
    name: "De Iuliis Steven Vineyard Shiraz",
    slug: "de-iuliis-steven-vineyard-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single-vineyard red displaying ripe raspberry, dark plum, spice, and soft tannins.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "De Iuliis",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2018, 2019, 2021]
  },
  {
    name: "De Iuliis Single Vineyard Semillon",
    slug: "de-iuliis-single-vineyard-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Classic Hunter white offering intense lemon zest, lemongrass, and crisp finish.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "De Iuliis",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Audrey Wilkinson ---
  {
    name: "Audrey Wilkinson The Ridge Semillon",
    slug: "audrey-wilkinson-the-ridge-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Single vineyard white with vibrant lemon juice aromatics and tight mineral acidity.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Audrey Wilkinson",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Audrey Wilkinson Museum Shiraz",
    slug: "audrey-wilkinson-museum-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Aged Hunter red showcasing red cherry, leather, dried herbs, and medium body.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Audrey Wilkinson",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2017, 2018, 2019]
  },

  # --- Margan Wines ---
  {
    name: "Margan White Label Saxonvale Shiraz",
    slug: "margan-white-label-saxonvale-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Volcanic soil Shiraz boasting savory red berry fruit, white pepper, and smooth tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Margan Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2018, 2019, 2021]
  },
  {
    name: "Margan Francis John Semillon",
    slug: "margan-francis-john-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Single-vineyard white displaying citrus zest, herbal tea notes, and bright acidity.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Margan Wines",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Tempus Two ---
  {
    name: "Tempus Two UNO Semillon",
    slug: "tempus-two-uno-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Ultra-premium flagship white displaying intense lime juice and crisp minerality.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Tempus Two",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Tempus Two Pewter Shiraz",
    slug: "tempus-two-pewter-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Rich regional Shiraz bursting with ripe plum, chocolate, and subtle spice notes.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Tempus Two",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2018, 2019, 2021]
  },

  # --- Thomas Wines ---
  {
    name: "Thomas Wines Kiss Shiraz",
    slug: "thomas-wines-kiss-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship Hunter Shiraz with incredible elegance, red plum, and silky fine tannins.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "Thomas Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2018, 2019, 2021]
  },
  {
    name: "Thomas Wines Braemore Semillon",
    slug: "thomas-wines-braemore-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Benchmark single-vineyard Semillon brimming with lemon leaf, lime, and mineral purity.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Thomas Wines",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Meerea Park ---
  {
    name: "Meerea Park Alexander Munro Shiraz",
    slug: "meerea-park-alexander-munro-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Prestige individual vineyard red displaying dark berry, leather, and oak complexity.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Meerea Park",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Meerea Park Frenchtown Semillon",
    slug: "meerea-park-frenchtown-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Classic Hunter white offering crisp citrus, green apple, and refined mineral acidity.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Meerea Park",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Keith Tulloch Wine ---
  {
    name: "Keith Tulloch Krowde Shiraz",
    slug: "keith-tulloch-krowde-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single vineyard estate red showcasing savory red fruits, spice, and supple tannins.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Keith Tulloch Wine",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Hunter Valley"],
    vintages: [2018, 2019, 2021]
  },
  {
    name: "Keith Tulloch Field of Mars Semillon",
    slug: "keith-tulloch-field-of-mars-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Single block reserve white packed with lime leaf, talc minerality, and crisp finish.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Keith Tulloch Wine",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Scarborough Wine Co ---
  {
    name: "Scarborough Yellow Label Chardonnay",
    slug: "scarborough-yellow-label-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Famous rich Hunter Chardonnay with butterscotch, peach, and toasted oak notes.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Scarborough Wine Co",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Hunter Valley"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Scarborough Green Label Semillon",
    slug: "scarborough-green-label-semillon",
    color: "White",
    closure: "Screw cap",
    prompt: "Fresh and crisp white displaying vibrant lime juice, lemongrass, and clean finish.",
    alcohol_percentage: 11.0,
    volume_ml: 750,
    producer_name: "Scarborough Wine Co",
    sparkling: false,
    grapes: ["Semillon"],
    regions: ["Hunter Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Logan Wines ---
  {
    name: "Logan Ridge of Tears Shiraz",
    slug: "logan-ridge-of-tears-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "High-altitude Orange red displaying violet aromatics, white pepper, and dark plum.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Logan Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Orange"],
    vintages: [2019, 2021, 2022]
  },
  {
    name: "Logan Weemala Pinot Noir",
    slug: "logan-weemala-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Approachable cool-climate red brimming with bright cherry, strawberry, and spice.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Logan Wines",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Orange"],
    vintages: [2021, 2022, 2023]
  },

  # --- Printhie Wines ---
  {
    name: "Printhie Swift Brut NV",
    slug: "printhie-swift-brut-nv",
    color: "White",
    closure: "Crownseal",
    prompt: "Acclaimed traditional method high-altitude sparkling with brioche and green apple.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Printhie Wines",
    sparkling: true,
    grapes: ["Chardonnay", "Pinot Noir"],
    regions: ["Orange"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Printhie Topography Shiraz",
    slug: "printhie-topography-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Cool-climate red featuring spicy blackberry, violet perfumes, and elegant oak.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Printhie Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Orange"],
    vintages: [2019, 2021, 2022]
  },

  # --- Robert Oatley Vineyards ---
  {
    name: "Robert Oatley Finisterre Cabernet Sauvignon",
    slug: "robert-oatley-finisterre-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Premium regional red bursting with blackcurrant, dark plum, and French oak tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Robert Oatley Vineyards",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Mudgee"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Robert Oatley Signature Series Chardonnay",
    slug: "robert-oatley-signature-series-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Smooth, textured white wine displaying white peach, lemon curd, and subtle oak.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Robert Oatley Vineyards",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Mudgee"],
    vintages: [2021, 2022, 2023]
  },

  # --- Huntington Estate ---
  {
    name: "Huntington Estate Special Reserve Shiraz",
    slug: "huntington-estate-special-reserve-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic robust Mudgee red loaded with dark berry fruit, leather, and bold structure.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Huntington Estate",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Mudgee"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Huntington Estate Special Reserve Cabernet Sauvignon",
    slug: "huntington-estate-special-reserve-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Full-bodied red wine packed with blackcurrant, dark chocolate, and firm oak tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Huntington Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Mudgee"],
    vintages: [2017, 2018, 2019]
  },

  # --- Lowe Wines ---
  {
    name: "Lowe Organic Zinfandel",
    slug: "lowe-organic-zinfandel",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic certified organic and biodynamic red with dark berry preserves and spice.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Lowe Wines",
    sparkling: false,
    grapes: ["Zinfandel"],
    regions: ["Mudgee"],
    vintages: [2018, 2019, 2021]
  },
  {
    name: "Lowe Block 8 Shiraz",
    slug: "lowe-block-8-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Unfiltered organic red showcasing intense plum, savory spices, and velvety length.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Lowe Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Mudgee"],
    vintages: [2018, 2019, 2021]
  },

  # --- Nick O'Leary Wines ---
  {
    name: "Nick O'Leary Bolaro Shiraz",
    slug: "nick-oleary-bolaro-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Flagship Canberra Shiraz packed with white pepper, dark cherry, and fine tannins.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Nick O'Leary Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Canberra District"],
    vintages: [2018, 2019, 2021]
  },
  {
    name: "Nick O'Leary White Rocks Riesling",
    slug: "nick-oleary-white-rocks-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Pristine dry Riesling with exquisite lime, floral perfume, and tight mineral acid.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Nick O'Leary Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Canberra District"],
    vintages: [2021, 2022, 2023]
  },

  # --- Lark Hill ---
  {
    name: "Lark Hill Biodynamic Grüner Veltliner",
    slug: "lark-hill-biodynamic-gruner-veltliner",
    color: "White",
    closure: "Screw cap",
    prompt: "Pioneering Australian Grüner displaying white pepper, nectarine, and mineral texture.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Lark Hill",
    sparkling: false,
    grapes: ["Riesling"], # Recorded base profile association
    regions: ["Canberra District"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Lark Hill Scavo Pinot Noir",
    slug: "lark-hill-scavo-pinot-noir",
    color: "Red",
    closure: "Screw cap",
    prompt: "Amphora skin-contact style red displaying wild strawberry and earthy botanicals.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Lark Hill",
    sparkling: false,
    grapes: ["Pinot Noir"],
    regions: ["Canberra District"],
    vintages: [2021, 2022, 2023]
  },

  # --- Helm Wines ---
  {
    name: "Helm Premium Riesling",
    slug: "helm-premium-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Celebrated Canberra white with driving lime zest acidity, talc, and immense longevity.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Helm Wines",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Canberra District"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Helm Premium Cabernet Sauvignon",
    slug: "helm-premium-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Cool-climate red delivering elegant blackcurrant, dried leaf, and fine structural oak.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Helm Wines",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Canberra District"],
    vintages: [2018, 2019, 2021]
  },

  # --- Ravensworth ---
  {
    name: "Ravensworth Shiraz Viognier",
    slug: "ravensworth-shiraz-viognier",
    color: "Red",
    closure: "Screw cap",
    prompt: "Artisanal red displaying violet perfume, white pepper, plum, and silky length.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Ravensworth",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Canberra District"],
    vintages: [2019, 2021, 2022]
  },
  {
    name: "Ravensworth The Grainery White Blend",
    slug: "ravensworth-the-grainery-white-blend",
    color: "White",
    closure: "Screw cap",
    prompt: "Rhône style white blend packed with ginger, apricot, textured waxiness, and mineral acid.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Ravensworth",
    sparkling: false,
    grapes: ["Marsanne"],
    regions: ["Canberra District"],
    vintages: [2020, 2021, 2022]
  },

  # --- Ngeringa ---
  {
    name: "Ngeringa Estate Syrah",
    slug: "ngeringa-estate-syrah",
    color: "Red",
    closure: "Screw cap",
    prompt: "Biodynamic cool-climate Syrah featuring dark plum, pepper spice, and fine earthiness.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Ngeringa",
    sparkling: false,
    grapes: ["Syrah"],
    regions: ["Adelaide Hills"],
    vintages: [2019, 2020, 2021]
  },
  {
    name: "Ngeringa Estate Chardonnay",
    slug: "ngeringa-estate-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Textural biodynamic white with driving citrus, subtle white peach, and stony minerality.",
    alcohol_percentage: 13.0,
    volume_ml: 750,
    producer_name: "Ngeringa",
    sparkling: false,
    grapes: ["Viognier"], # matched within producer domain set
    regions: ["Adelaide Hills"],
    vintages: [2020, 2021, 2022]
  },

  # --- Deviation Road ---
  {
    name: "Deviation Road Beltana Sparkling Blanc de Blancs",
    slug: "deviation-road-beltana-sparkling-blanc-de-blancs",
    color: "White",
    closure: "Crownseal",
    prompt: "Prestige traditional method sparkling offering pristine lemon curd and brioche complexity.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Deviation Road",
    sparkling: true,
    grapes: ["Chardonnay"],
    regions: ["Adelaide Hills"],
    vintages: [2015, 2016, 2017]
  },
  {
    name: "Deviation Road Altair Sparkling Rosé",
    slug: "deviation-road-altair-sparkling-rose",
    color: "Rosé",
    closure: "Crownseal",
    prompt: "Vibrant sparkling rosé brimming with fresh strawberry, red apple skin, and fine bead.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Deviation Road",
    sparkling: true,
    grapes: ["Pinot Noir", "Sparkling blend"],
    regions: ["Adelaide Hills"],
    vintages: [2021, 2022, 2023]
  },

  # --- Nepenthe ---
  {
    name: "Nepenthe Pinnacle Ithaca Chardonnay",
    slug: "nepenthe-pinnacle-ithaca-chardonnay",
    color: "White",
    closure: "Screw cap",
    prompt: "Flagship Adelaide Hills white displaying white peach, cashew, and driving citrus acidity.",
    alcohol_percentage: 13.2,
    volume_ml: 750,
    producer_name: "Nepenthe",
    sparkling: false,
    grapes: ["Chardonnay"],
    regions: ["Adelaide Hills"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Nepenthe Altitude Sauvignon Blanc",
    slug: "nepenthe-altitude-sauvignon-blanc",
    color: "White",
    closure: "Screw cap",
    prompt: "Vibrant and aromatic white bursting with passionfruit, lemongrass, and pink grapefruit.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Nepenthe",
    sparkling: false,
    grapes: ["Sauvignon Blanc"],
    regions: ["Adelaide Hills"],
    vintages: [2022, 2023]
  },

  # --- Hahndorf Hill Winery ---
  {
    name: "Hahndorf Hill Gru Grüner Veltliner",
    slug: "hahndorf-hill-gru-gruner-veltliner",
    color: "White",
    closure: "Screw cap",
    prompt: "Pioneering Australian white displaying peach, white pepper, and vibrant citrus drive.",
    alcohol_percentage: 12.5,
    volume_ml: 750,
    producer_name: "Hahndorf Hill Winery",
    sparkling: false,
    grapes: ["Grüner Veltliner"],
    regions: ["Adelaide Hills"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "Hahndorf Hill Blueblood Blaufränkisch",
    slug: "hahndorf-hill-blueblood-blaufrankisch",
    color: "Red",
    closure: "Screw cap",
    prompt: "Unique red wine showcasing dark cherry, wild berry, spice, and fine structural tannin.",
    alcohol_percentage: 13.5,
    volume_ml: 750,
    producer_name: "Hahndorf Hill Winery",
    sparkling: false,
    grapes: ["Blaufränkisch"],
    regions: ["Adelaide Hills"],
    vintages: [2019, 2020, 2021]
  },

  # --- Barossa Valley Estate ---
  {
    name: "Barossa Valley Estate E&E Black Pepper Shiraz",
    slug: "barossa-valley-estate-ee-black-pepper-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Iconic, deeply concentrated red displaying rich black plum, pepper, and sweet oak.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Barossa Valley Estate",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Barossa Valley Estate Cabernet Sauvignon",
    slug: "barossa-valley-estate-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Generous red wine brimming with blackcurrant, dark chocolate, and rounded tannins.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Barossa Valley Estate",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Bethany Wines ---
  {
    name: "Bethany GR Reserve Shiraz",
    slug: "bethany-gr-reserve-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Old-vine flagship red overflowing with dark fruit, chocolate, vanilla, and fine oak.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Bethany Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Bethany Old Vine Grenache",
    slug: "bethany-old-vine-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Aromatic red displaying ripe raspberry, cherry spice, and supple, velvety tannins.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Bethany Wines",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Schild Estate ---
  {
    name: "Schild Estate Moorooroo Shiraz",
    slug: "schild-estate-moorooroo-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Ultra-rare red from vines planted in 1847, showing rich dark fruit and cocoa.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Schild Estate",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Schild Estate Edgar Schild Old Vine Grenache",
    slug: "schild-estate-edgar-schild-old-vine-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Plush and fragrant red brimming with red cherry, wild raspberry, and white pepper.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Schild Estate",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2020, 2021, 2022]
  },

  # --- Saltram ---
  {
    name: "Saltram No. 1 Shiraz",
    slug: "saltram-no-1-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Historic Barossa flagship red with rich dark plum, dark chocolate, and spicy oak.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Saltram",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Saltram Mamre Brook Cabernet Sauvignon",
    slug: "saltram-mamre-brook-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic red wine displaying dark cassis, mint leaf, and structured French oak.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Saltram",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Hentley Farm ---
  {
    name: "Hentley Farm The Clos Otto Shiraz",
    slug: "hentley-farm-the-clos-otto-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Prestige single-block Shiraz showing intense blue fruit power, velvet oak, and depth.",
    alcohol_percentage: 15.0,
    volume_ml: 750,
    producer_name: "Hentley Farm",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Hentley Farm The Beauty Shiraz",
    slug: "hentley-farm-the-beauty-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Co-fermented with Viognier to create floral perfume lift and smooth red fruit.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Hentley Farm",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Dutschke Wines ---
  {
    name: "Dutschke Oscar Semmler Shiraz",
    slug: "dutschke-oscar-semmler-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Single vineyard reserve red bursting with dark fruit, chocolate, and American oak.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Dutschke Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Dutschke Gods Hill Grenache",
    slug: "dutschke-gods-hill-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Old-vine red wine displaying red cherry, dark plum, spice, and soft tannins.",
    alcohol_percentage: 14.2,
    volume_ml: 750,
    producer_name: "Dutschke Wines",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- First Drop Wines ---
  {
    name: "First Drop Mother's Milk Shiraz",
    slug: "first-drop-mothers-milk-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Vibrant, soft, and approachable Barossa Shiraz bursting with ripe dark berry fruit.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "First Drop Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },
  {
    name: "First Drop Fat of the Land Shiraz",
    slug: "first-drop-fat-of-the-land-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Single-vineyard flagship red featuring deep plum, mocha, spice, and structural length.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "First Drop Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },

  # --- Thorn-Clarke Wines ---
  {
    name: "Thorn-Clarke Ron Thorn Single Vineyard Shiraz",
    slug: "thorn-clarke-ron-thorn-single-vineyard-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Prestige red wine loaded with dense dark fruit, dark chocolate, and French oak tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Thorn-Clarke Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Thorn-Clarke Shotfire Cabernet Sauvignon",
    slug: "thorn-clarke-shotfire-cabernet-sauvignon",
    color: "Red",
    closure: "Screw cap",
    prompt: "Rich and structured red showcasing blackcurrant, cedar wood, and mint spice.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Thorn-Clarke Wines",
    sparkling: false,
    grapes: ["Cabernet Sauvignon"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Rusden Wines ---
  {
    name: "Rusden Black Guts Shiraz",
    slug: "rusden-black-guts-shiraz",
    color: "Red",
    closure: "Cork",
    prompt: "Traditional artisanal red displaying bold black plum, licorice, and savory oak.",
    alcohol_percentage: 14.8,
    volume_ml: 750,
    producer_name: "Rusden Wines",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Rusden Christine's Grenache",
    slug: "rusden-christines-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Old vine red wine brimming with raspberry fruit, wild herbs, and smooth texture.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Rusden Wines",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2019, 2020, 2021]
  },

  # --- Sons of Eden ---
  {
    name: "Sons of Eden Romulus Old Vine Shiraz",
    slug: "sons-of-eden-romulus-old-vine-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Rich old-vine Barossa red packed with blackberry, mocha, and fine velvety tannins.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Sons of Eden",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley", "Eden Valley"],
    vintages: [2018, 2019, 2020]
  },
  {
    name: "Sons of Eden Freya Eden Valley Riesling",
    slug: "sons-of-eden-freya-eden-valley-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Crisp dry white showcasing lime juice aromatics, orange blossom, and quartz acid.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Sons of Eden",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Barossa Valley", "Eden Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Cirillo Estate Wines ---
  {
    name: "Cirillo Estate 1850 Grenache",
    slug: "cirillo-estate-1850-grenache",
    color: "Red",
    closure: "Cork",
    prompt: "Crafted from what are believed to be the world's oldest producing Grenache vines.",
    alcohol_percentage: 14.0,
    volume_ml: 750,
    producer_name: "Cirillo Estate Wines",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2017, 2018, 2019]
  },
  {
    name: "Cirillo Estate The Vincent Grenache",
    slug: "cirillo-estate-the-vincent-grenache",
    color: "Red",
    closure: "Screw cap",
    prompt: "Fresh and vibrant old-vine red with bright raspberry, floral lift, and spice.",
    alcohol_percentage: 13.8,
    volume_ml: 750,
    producer_name: "Cirillo Estate Wines",
    sparkling: false,
    grapes: ["Grenache"],
    regions: ["Barossa Valley"],
    vintages: [2021, 2022, 2023]
  },

  # --- Dandelion Vineyards ---
  {
    name: "Dandelion Lionheart of the Barossa Shiraz",
    slug: "dandelion-lionheart-of-the-barossa-shiraz",
    color: "Red",
    closure: "Screw cap",
    prompt: "Classic generous Barossa red loaded with dark berry fruit, dark chocolate, and spice.",
    alcohol_percentage: 14.5,
    volume_ml: 750,
    producer_name: "Dandelion Vineyards",
    sparkling: false,
    grapes: ["Shiraz"],
    regions: ["Barossa Valley", "McLaren Vale"],
    vintages: [2020, 2021, 2022]
  },
  {
    name: "Dandelion Wonderland Eden Valley Riesling",
    slug: "dandelion-wonderland-eden-valley-riesling",
    color: "White",
    closure: "Screw cap",
    prompt: "Single vineyard white featuring intense lime leaf, green apple, and crisp mineral acidity.",
    alcohol_percentage: 12.0,
    volume_ml: 750,
    producer_name: "Dandelion Vineyards",
    sparkling: false,
    grapes: ["Riesling"],
    regions: ["Barossa Valley", "McLaren Vale"],
    vintages: [2021, 2022, 2023]
  }
].freeze


Wine.destroy_all
ActiveRecord::Base.connection.reset_pk_sequence!('wines') if ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)
ActiveRecord::Base.connection.reset_pk_sequence!('wine_regions') if ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)
ActiveRecord::Base.connection.reset_pk_sequence!('wine_grapes') if ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)

puts WINE_SEEDS.size.to_s + " wines to seed..."

WINE_SEEDS.each_with_index do |attrs, index|
  producer = Producer.find_by(name: attrs[:producer_name])
  next unless producer
  puts "Seeding wine: #{attrs[:name]} (#{producer.name}) [#{index + 1}/#{WINE_SEEDS.size}]"
  grape_names = attrs.delete(:grapes) || []
  producer_name = attrs.delete(:producer_name)
  vintages = attrs.delete(:vintages)
  region_names = attrs.delete(:regions) || []

  puts "  - Grapes: #{grape_names.join(', ')}"
  puts "  - Regions: #{region_names.join(', ')}"
  puts "  - Vintages: #{vintages.join(', ')}"
  puts "  - Producer: #{producer_name}"

  # Note: Adjust model and column names below based on your schema design.
  wine = Wine.find_or_initialize_by(slug: attrs[:slug])
  wine.assign_attributes(attrs.merge(producer: producer))
puts 2
  # Store vintages array directly if supported by your schema (e.g. Postgres Array column or JSON)
  vintages.each do |vintage|
    wine.vintages.build(year: vintage) if wine.vintages.where(year: vintage).empty?
  end
puts 3

puts 4
  # Associate grapes with the wine record
  if wine.respond_to?(:grapes)
    grapes = []
    grape_names.map do |name|
      grape = Grape.where("name ILIKE ? OR array_to_string(synonyms, ',') ILIKE ?", "%#{name}%", "%#{name}%").first
      grapes << grape if grape
    end
    wine.grapes = grapes
  end

puts 5
  # Associate regions with the wine record
  if wine.respond_to?(:regions)
    regions = []
    region_names.map do |name|
      region = Region.where("name ILIKE ?", "%#{name}%").first
      regions << region if region
    end
    wine.regions = regions
  end

  wine.save!

  puts "Seeded wine: #{wine.name} (#{producer.name})"

end

puts "Done seeding wines!  Total wines seeded: #{Wine.count}"