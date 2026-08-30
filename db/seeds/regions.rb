# db/seeds/regions.rb
#
# Seeds Region records as a nested tree: Country -> State -> Region -> Region -> Region
# Every level past the country is just another nested Region — there is no
# separate `subregion` attribute/column; depth varies by branch.
#
# AUSTRALIA is sourced directly from the official Wine Australia Register of
# Protected Geographical Indications:
#   https://www.wineaustralia.com/labelling/register-of-protected-gis-and-other-terms/geographical-indications
# fetched and verified against this file. Structure: State -> Zone -> Region -> Subregion.
# Notes on a few entries that aren't ordinary state/zone/region/subregion nodes:
#   - "Adelaide (super zone — Mount Lofty Ranges, Fleurieu, Barossa)" is a
#     registered South Australian super-zone spanning those three zones.
#   - "South Eastern Australia (multi-state super-zone)" is a registered GI
#     covering all of NSW, Victoria and Tasmania plus parts of Queensland
#     and South Australia — kept as its own top-level entry since it does
#     not fit inside a single state.
#   - Tasmania, the Northern Territory, and the Australian Capital Territory
#     have NO registered zones/regions/subregions as of this register — they
#     are included as states with no children rather than omitted, since
#     they are real, currently registered GIs.
#
# Other countries follow Country -> Region -> Region (no state tier, since
# most non-Australian systems don't use one) down to the appellation level;
# this data has not been re-verified against each country's own official
# registry the way Australia was above.
#
# Usage: rails runner db/seeds/regions.rb
#   or require it from db/seeds.rb
#
# Assumes a self-referential Region model, e.g.:
#   create_table :regions do |t|
#     t.string :name, null: false
#     t.references :parent, foreign_key: { to_table: :regions }, null: true
#   end
#   belongs_to :parent, class_name: "Region", optional: true
#   has_many :children, class_name: "Region", foreign_key: :parent_id

REGIONS = {
  "Australia" => {
    "South Australia" => {
      "Adelaide (super zone — Mount Lofty Ranges, Fleurieu, Barossa)" => {},
      "Barossa" => {
        "Barossa Valley" => {},
        "Eden Valley" => {
          "High Eden" => {}
        }
      },
      "Far North" => {
        "Southern Flinders Ranges" => {}
      },
      "Fleurieu" => {
        "Currency Creek" => {},
        "Kangaroo Island" => {},
        "Langhorne Creek" => {},
        "McLaren Vale" => {},
        "Southern Fleurieu" => {}
      },
      "Limestone Coast" => {
        "Coonawarra" => {},
        "Mount Benson" => {},
        "Mount Gambier" => {},
        "Padthaway" => {},
        "Robe" => {},
        "Wrattonbully" => {}
      },
      "Lower Murray" => {
        "Riverland" => {}
      },
      "Mount Lofty Ranges" => {
        "Adelaide Hills" => {
          "Lenswood" => {},
          "Piccadilly Valley" => {}
        },
        "Adelaide Plains" => {},
        "Clare Valley" => {}
      },
      "The Peninsulas" => {}
    },
    "New South Wales" => {
      "Big Rivers" => {
        "Murray Darling" => {},
        "Perricoota" => {},
        "Riverina" => {},
        "Swan Hill" => {}
      },
      "Central Ranges" => {
        "Cowra" => {},
        "Mudgee" => {},
        "Orange" => {}
      },
      "Hunter Valley" => {
        "Hunter" => {
          "Broke Fordwich" => {},
          "Pokolbin" => {},
          "Upper Hunter Valley" => {}
        }
      },
      "Northern Rivers" => {
        "Hastings River" => {}
      },
      "Northern Slopes" => {
        "New England Australia" => {}
      },
      "South Coast" => {
        "Shoalhaven Coast" => {},
        "Southern Highlands" => {}
      },
      "Southern New South Wales" => {
        "Canberra District" => {},
        "Gundagai" => {},
        "Hilltops" => {},
        "Tumbarumba" => {}
      },
      "Western Plains" => {}
    },
    "Western Australia" => {
      "Central Western Australia" => {},
      "Eastern Plains - Inland and North of Western Australia" => {},
      "Greater Perth" => {
        "Peel" => {},
        "Perth Hills" => {},
        "Swan District" => {
          "Swan Valley" => {}
        }
      },
      "South West Australia" => {
        "Blackwood Valley" => {},
        "Geographe" => {},
        "Great Southern" => {
          "Albany" => {},
          "Denmark" => {},
          "Frankland River" => {},
          "Mount Barker" => {},
          "Porongurup" => {}
        },
        "Manjimup" => {},
        "Margaret River" => {},
        "Pemberton" => {}
      },
      "West Australian South East Coastal" => {}
    },
    "Queensland" => {
      "Granite Belt" => {},
      "South Burnett" => {}
    },
    "Victoria" => {
      "Central Victoria" => {
        "Bendigo" => {},
        "Goulburn Valley" => {
          "Nagambie Lakes" => {}
        },
        "Heathcote" => {},
        "Strathbogie Ranges" => {},
        "Upper Goulburn" => {}
      },
      "Gippsland" => {},
      "North East Victoria" => {
        "Alpine Valleys" => {},
        "Beechworth" => {},
        "Glenrowan" => {},
        "King Valley" => {},
        "Rutherglen" => {}
      },
      "North West Victoria" => {
        "Murray Darling" => {},
        "Swan Hill" => {}
      },
      "Port Phillip" => {
        "Geelong" => {},
        "Macedon Ranges" => {},
        "Mornington Peninsula" => {},
        "Sunbury" => {},
        "Yarra Valley" => {}
      },
      "Western Victoria" => {
        "Grampians" => {
          "Great Western" => {}
        },
        "Henty" => {},
        "Pyrenees" => {}
      }
    },
    "Tasmania" => {},
    "Northern Territory" => {},
    "Australian Capital Territory" => {},
    "South Eastern Australia (multi-state super-zone)" => {}
  },
  "Brazil" => {
    "Rio Grande do Sul" => {
      "Serra Gaúcha" => {
        "Vale dos Vinhedos" => {},
        "Altos Montes" => {},
        "Monte Belo" => {},
        "Farroupilha" => {},
        "Pinto Bandeira" => {},
        "Altos de Pinto Bandeira" => {}
      },
      "Campanha Gaúcha" => {},
      "Campos de Cima da Serra" => {}
    },

    "Santa Catarina" => {
      "Serra Catarinense" => {
        "Vinhos de Altitude de Santa Catarina" => {}
      },
      "Planalto Catarinense" => {}
    },

    "Bahia" => {
      "Vale do São Francisco" => {}
    },

    "Pernambuco" => {
      "Vale do São Francisco" => {}
    },

    "Minas Gerais" => {
      "Sul de Minas" => {
        "Vinhos de Inverno Sul de Minas" => {}
      }
    },

    "Paraná" => {
      "Bituruna" => {
        "Vinhos de Bituruna" => {}
      },
      "Norte do Paraná" => {}
    },

    "Goiás" => {
      "Goiás" => {}
    },

    "Espírito Santo" => {
      "Espírito Santo" => {}
    },
    "São Paulo" => {
      "Serra da Mantiqueira" => {},
      "São Roque" => {}
    }
  },
  "France" => {
    "Bordeaux" => {
      "Médoc" => {},
      "Margaux" => {},
      "Saint-Julien" => {},
      "Pauillac" => {},
      "Saint-Estèphe" => {},
      "Pessac-Léognan" => {},
      "Graves" => {},
      "Saint-Émilion" => {},
      "Pomerol" => {},
      "Sauternes" => {},
      "Barsac" => {},
      "Entre-Deux-Mers" => {}
    },
    "Burgundy" => {
      "Chablis" => {},
      "Côte de Nuits" => {},
      "Gevrey-Chambertin" => {},
      "Vosne-Romanée" => {},
      "Nuits-Saint-Georges" => {},
      "Côte de Beaune" => {},
      "Meursault" => {},
      "Puligny-Montrachet" => {},
      "Pommard" => {},
      "Volnay" => {},
      "Mâconnais" => {},
      "Beaujolais" => {}
    },
    "Champagne" => {
      "Montagne de Reims" => {},
      "Vallée de la Marne" => {},
      "Côte des Blancs" => {},
      "Côte des Bar" => {}
    },
    "Rhône Valley" => {
      "Côte-Rôtie" => {},
      "Condrieu" => {},
      "Hermitage" => {},
      "Crozes-Hermitage" => {},
      "Saint-Joseph" => {},
      "Cornas" => {},
      "Châteauneuf-du-Pape" => {},
      "Gigondas" => {},
      "Vacqueyras" => {},
      "Côtes du Rhône" => {}
    },
    "Loire Valley" => {
      "Sancerre" => {},
      "Pouilly-Fumé" => {},
      "Vouvray" => {},
      "Chinon" => {},
      "Bourgueil" => {},
      "Muscadet" => {},
      "Savennières" => {},
      "Saumur-Champigny" => {}
    },
    "Alsace" => {
      "Alsace Grand Cru" => {},
      "Crémant d'Alsace" => {}
    },
    "Provence" => {
      "Côtes de Provence" => {},
      "Bandol" => {},
      "Cassis" => {},
      "Bellet" => {}
    },
    "Languedoc-Roussillon" => {
      "Corbières" => {},
      "Minervois" => {},
      "Faugères" => {},
      "Fitou" => {},
      "Banyuls" => {},
      "Picpoul de Pinet" => {}
    },
    "Jura" => {
      "Arbois" => {},
      "Château-Chalon" => {},
      "L'Étoile" => {},
      "Côtes du Jura" => {}
    },
    "Savoie" => {
      "Apremont" => {},
      "Abymes" => {},
      "Chignin" => {}
    },
    "Southwest France" => {
      "Cahors" => {},
      "Madiran" => {},
      "Jurançon" => {},
      "Bergerac" => {}
    }
  },
  "Italy" => {
    "Piedmont" => {
      "Barolo" => {},
      "Barbaresco" => {},
      "Barbera d'Alba" => {},
      "Barbera d'Asti" => {},
      "Dolcetto d'Alba" => {},
      "Gavi" => {},
      "Roero" => {},
      "Asti" => {}
    },
    "Tuscany" => {
      "Chianti" => {},
      "Chianti Classico" => {},
      "Brunello di Montalcino" => {},
      "Vino Nobile di Montepulciano" => {},
      "Bolgheri" => {},
      "Maremma" => {}
    },
    "Veneto" => {
      "Valpolicella" => {},
      "Amarone della Valpolicella" => {},
      "Soave" => {},
      "Bardolino" => {},
      "Prosecco (Conegliano Valdobbiadene)" => {}
    },
    "Friuli-Venezia Giulia" => {
      "Collio" => {},
      "Colli Orientali del Friuli" => {},
      "Friuli Isonzo" => {}
    },
    "Umbria" => {
      "Montefalco Sagrantino" => {},
      "Orvieto" => {}
    },
    "Abruzzo" => {
      "Montepulciano d'Abruzzo" => {},
      "Trebbiano d'Abruzzo" => {}
    },
    "Campania" => {
      "Taurasi" => {},
      "Fiano di Avellino" => {},
      "Greco di Tufo" => {}
    },
    "Puglia" => {
      "Primitivo di Manduria" => {},
      "Salice Salentino" => {},
      "Castel del Monte" => {}
    },
    "Sicily" => {
      "Etna" => {},
      "Cerasuolo di Vittoria" => {},
      "Marsala" => {}
    },
    "Lombardy" => {
      "Franciacorta" => {},
      "Valtellina" => {},
      "Oltrepò Pavese" => {}
    },
    "Emilia-Romagna" => {
      "Lambrusco di Sorbara" => {},
      "Lambrusco Grasparossa" => {}
    },
    "Sardinia" => {
      "Vermentino di Gallura" => {},
      "Cannonau di Sardegna" => {}
    }
  },
  "Spain" => {
    "Rioja" => {
      "Rioja Alta" => {},
      "Rioja Alavesa" => {},
      "Rioja Oriental" => {}
    },
    "Ribera del Duero" => {
      "Ribera del Duero DO" => {}
    },
    "Catalonia" => {
      "Priorat" => {},
      "Penedès" => {},
      "Montsant" => {},
      "Cava" => {}
    },
    "Galicia" => {
      "Rías Baixas" => {},
      "Ribeira Sacra" => {},
      "Valdeorras" => {},
      "Bierzo" => {}
    },
    "Andalusia" => {
      "Jerez-Xérès-Sherry" => {},
      "Montilla-Moriles" => {},
      "Málaga" => {}
    },
    "Castilla y León" => {
      "Rueda" => {},
      "Toro" => {},
      "Cigales" => {}
    },
    "Castilla-La Mancha" => {
      "La Mancha" => {},
      "Valdepeñas" => {}
    },
    "Levante" => {
      "Jumilla" => {},
      "Yecla" => {},
      "Alicante" => {},
      "Utiel-Requena" => {}
    },
    "Navarra" => {
      "Navarra DO" => {}
    },
    "Basque Country" => {
      "Txakolí (Getariako Txakolina)" => {}
    }
  },
  "Portugal" => {
    "Douro" => {
      "Douro DOC" => {},
      "Porto (Port)" => {}
    },
    "Vinho Verde" => {
      "Vinho Verde DOC" => {}
    },
    "Dão" => {
      "Dão DOC" => {}
    },
    "Bairrada" => {
      "Bairrada DOC" => {}
    },
    "Alentejo" => {
      "Alentejo DOC" => {}
    },
    "Setúbal Peninsula" => {
      "Setúbal DOC" => {},
      "Palmela" => {}
    },
    "Madeira" => {
      "Madeira DOC" => {}
    }
  },
  "Germany" => {
    "Mosel" => {
      "Mosel DO" => {}
    },
    "Rheingau" => {
      "Rheingau DO" => {}
    },
    "Rheinhessen" => {
      "Rheinhessen DO" => {}
    },
    "Pfalz" => {
      "Pfalz DO" => {}
    },
    "Nahe" => {
      "Nahe DO" => {}
    },
    "Baden" => {
      "Baden DO" => {}
    },
    "Franken" => {
      "Franken DO" => {}
    }
  },
  "Austria" => {
    "Wachau" => {
      "Wachau DAC" => {}
    },
    "Kamptal" => {
      "Kamptal DAC" => {}
    },
    "Kremstal" => {
      "Kremstal DAC" => {}
    },
    "Burgenland" => {
      "Neusiedlersee DAC" => {},
      "Mittelburgenland DAC" => {},
      "Leithaberg DAC" => {}
    },
    "Weinviertel" => {
      "Weinviertel DAC" => {}
    },
    "Styria" => {
      "Südsteiermark DAC" => {}
    }
  },
  "Greece" => {
    "Santorini" => {
      "Santorini PDO" => {}
    },
    "Macedonia" => {
      "Naoussa PDO" => {},
      "Amyndeon PDO" => {}
    },
    "Peloponnese" => {
      "Nemea PDO" => {},
      "Mantinia PDO" => {}
    },
    "Crete" => {
      "Peza PDO" => {}
    }
  },
  "Hungary" => {
    "Tokaj" => {
      "Tokaji PDO" => {}
    },
    "Eger" => {
      "Eger PDO (Egri Bikavér)" => {}
    },
    "Villány" => {
      "Villány PDO" => {}
    }
  },
  "Georgia" => {
    "Kakheti" => {
      "Kakheti PDO" => {}
    },
    "Kartli" => {
      "Kartli PDO" => {}
    },
    "Imereti" => {
      "Imereti PDO" => {}
    }
  },
  "Romania" => {
    "Dealu Mare" => {
      "Dealu Mare DOC" => {}
    },
    "Moldavia" => {
      "Cotnari DOC" => {}
    }
  },
  "Croatia" => {
    "Istria" => {
      "Istria PDO" => {}
    },
    "Dalmatia" => {
      "Pelješac" => {},
      "Hvar" => {}
    }
  },
#   "Poland" => {
#   "Małopolska" => {
#     "Jasło" => {},
#     "Wieliczka" => {},
#     "Tuchów" => {}
#   },
#   "Lubusz Voivodeship" => {
#     "Zielona Góra" => {},
#     "Gorzów Wielkopolski" => {}
#   },
#   "Lower Silesia" => {
#     "Wrocław" => {},
#     "Trzebnica" => {}
#   },
#   "Podkarpackie" => {
#     "Przemyśl" => {},
#     "Jasło" => {}
#   },
#   "Masovia" => {
#     "Warsaw" => {}
#   },
#   "Pomerania" => {
#     "Gdańsk" => {}
#   },
#   "Greater Poland" => {
#     "Poznań" => {}
#   },
#   "Silesia" => {
#     "Katowice" => {}
#   }
# },
 "Poland" => {
    "Lubusz Voivodeship" => {
      "Zielona Góra" => {},
      "Lubuskie Wine Region" => {}
    },

    "Lower Silesian Voivodeship" => {
      "Lower Silesia" => {},
      "Trzebnica Hills" => {}
    },

    "Lesser Poland Voivodeship" => {
      "Małopolska" => {},
      "Sandomierz Upland" => {}
    },

    "Podkarpackie Voivodeship" => {
      "Podkarpacie" => {},
      "Jasło" => {}
    },

    "Lublin Voivodeship" => {
      "Lubelskie" => {}
    },

    "Świętokrzyskie Voivodeship" => {
      "Świętokrzyskie" => {}
    },

    "Silesian Voivodeship" => {
      "Silesia" => {}
    },

    "Greater Poland Voivodeship" => {
      "Wielkopolska" => {}
    },

    "West Pomeranian Voivodeship" => {
      "West Pomerania" => {}
    }
  },
  "United States" => {
    "California" => {
      "Napa Valley AVA" => {},
      "Sonoma County AVA" => {},
      "Russian River Valley AVA" => {},
      "Paso Robles AVA" => {},
      "Santa Barbara County AVA" => {},
      "Central Coast AVA" => {}
    },
    "Oregon" => {
      "Willamette Valley AVA" => {},
      "Dundee Hills AVA" => {}
    },
    "Washington State" => {
      "Columbia Valley AVA" => {},
      "Walla Walla Valley AVA" => {}
    },
    "New York" => {
      "Finger Lakes AVA" => {},
      "Long Island AVA" => {}
    }
  },
  "Chile" => {
    "Central Valley" => {
      "Maipo Valley" => {},
      "Rapel Valley" => {},
      "Colchagua Valley" => {},
      "Curicó Valley" => {}
    },
    "Aconcagua" => {
      "Aconcagua Valley" => {},
      "Casablanca Valley" => {},
      "San Antonio Valley" => {}
    },
    "Southern Regions" => {
      "Maule Valley" => {},
      "Itata Valley" => {},
      "Bío Bío Valley" => {}
    }
  },
  "Argentina" => {
    "Mendoza" => {
      "Luján de Cuyo" => {},
      "Uco Valley" => {},
      "Maipú" => {}
    },
    "Salta" => {
      "Cafayate" => {}
    },
    "Patagonia" => {
      "Río Negro" => {}
    }
  },
  "New Zealand" => {
    "Marlborough" => {
      "Marlborough GI" => {}
    },
    "Central Otago" => {
      "Central Otago GI" => {}
    },
    "Hawke's Bay" => {
      "Hawke's Bay GI" => {}
    },
    "Martinborough" => {
      "Martinborough GI" => {}
    }
  },
  "South Africa" => {
    "Western Cape" => {
      "Stellenbosch" => {},
      "Paarl" => {},
      "Swartland" => {},
      "Constantia" => {},
      "Walker Bay" => {}
    }
  },
  "Uruguay" => {
    "Canelones" => {
      "Canelones DO" => {}
    },
    "Maldonado" => {
      "Maldonado DO" => {}
    }
  }
}

def seed_regions(tree, parent = nil)
  tree.each do |name, children|
    region = Region.find_or_create_by!(name: name, parent: parent)
    seed_regions(children, region) if children.is_a?(Hash) && children.any?
  end
end

seed_regions(REGIONS)

puts "Done. Seeded #{Region.count} region records."