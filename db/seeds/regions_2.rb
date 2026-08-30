# db/seeds/regions.rb
#
# Seeds Region records as a nested tree: Country -> State/Region -> Appellation
# Usage: rails runner db/seeds/regions.rb

Region.delete_all
ActiveRecord::Base.connection.reset_pk_sequence!('regions')

REGIONS = {
  "Australia" => {
    "South Australia" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Adelaide (super zone - Mount Lofty Ranges, Fleurieu, Barossa)" => { is_state: false, is_appellation: false },
        "Barossa" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Barossa Valley" => { is_state: false, is_appellation: true },
            "Eden Valley" => {
              is_state: false,
              is_appellation: true,
              children: {
                "High Eden" => { is_state: false, is_appellation: true }
              }
            }
          }
        },
        "Far North" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Southern Flinders Ranges" => { is_state: false, is_appellation: true }
          }
        },
        "Fleurieu" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Currency Creek" => { is_state: false, is_appellation: true },
            "Kangaroo Island" => { is_state: false, is_appellation: true },
            "Langhorne Creek" => { is_state: false, is_appellation: true },
            "McLaren Vale" => { is_state: false, is_appellation: true },
            "Southern Fleurieu" => { is_state: false, is_appellation: true }
          }
        },
        "Limestone Coast" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Coonawarra" => { is_state: false, is_appellation: true },
            "Mount Benson" => { is_state: false, is_appellation: true },
            "Mount Gambier" => { is_state: false, is_appellation: true },
            "Padthaway" => { is_state: false, is_appellation: true },
            "Robe" => { is_state: false, is_appellation: true },
            "Wrattonbully" => { is_state: false, is_appellation: true }
          }
        },
        "Lower Murray" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Riverland" => { is_state: false, is_appellation: true }
          }
        },
        "Mount Lofty Ranges" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Adelaide Hills" => {
              is_state: false,
              is_appellation: true,
              children: {
                "Lenswood" => { is_state: false, is_appellation: true },
                "Piccadilly Valley" => { is_state: false, is_appellation: true }
              }
            },
            "Adelaide Plains" => { is_state: false, is_appellation: true },
            "Clare Valley" => { is_state: false, is_appellation: true }
          }
        },
        "The Peninsulas" => { is_state: false, is_appellation: true }
      }
    },
    "New South Wales" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Big Rivers" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Murray Darling" => { is_state: false, is_appellation: true },
            "Perricoota" => { is_state: false, is_appellation: true },
            "Riverina" => { is_state: false, is_appellation: true },
            "Swan Hill" => { is_state: false, is_appellation: true }
          }
        },
        "Central Ranges" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Cowra" => { is_state: false, is_appellation: true },
            "Mudgee" => { is_state: false, is_appellation: true },
            "Orange" => { is_state: false, is_appellation: true }
          }
        },
        "Hunter Valley" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Hunter" => {
              is_state: false,
              is_appellation: true,
              children: {
                "Broke Fordwich" => { is_state: false, is_appellation: true },
                "Pokolbin" => { is_state: false, is_appellation: true },
                "Upper Hunter Valley" => { is_state: false, is_appellation: true }
              }
            }
          }
        },
        "Northern Rivers" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Hastings River" => { is_state: false, is_appellation: true }
          }
        },
        "Northern Slopes" => {
          is_state: false,
          is_appellation: false,
          children: {
            "New England Australia" => { is_state: false, is_appellation: true }
          }
        },
        "South Coast" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Shoalhaven Coast" => { is_state: false, is_appellation: true },
            "Southern Highlands" => { is_state: false, is_appellation: true }
          }
        },
        "Southern New South Wales" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Canberra District" => { is_state: false, is_appellation: true },
            "Gundagai" => { is_state: false, is_appellation: true },
            "Hilltops" => { is_state: false, is_appellation: true },
            "Tumbarumba" => { is_state: false, is_appellation: true }
          }
        },
        "Western Plains" => { is_state: false, is_appellation: false }
      }
    },
    "Western Australia" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Central Western Australia" => { is_state: false, is_appellation: false },
        "Eastern Plains - Inland and North of Western Australia" => { is_state: false, is_appellation: false },
        "Greater Perth" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Peel" => { is_state: false, is_appellation: true },
            "Perth Hills" => { is_state: false, is_appellation: true },
            "Swan District" => {
              is_state: false,
              is_appellation: true,
              children: {
                "Swan Valley" => { is_state: false, is_appellation: true }
              }
            }
          }
        },
        "South West Australia" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Blackwood Valley" => { is_state: false, is_appellation: true },
            "Geographe" => { is_state: false, is_appellation: true },
            "Great Southern" => {
              is_state: false,
              is_appellation: true,
              children: {
                "Albany" => { is_state: false, is_appellation: true },
                "Denmark" => { is_state: false, is_appellation: true },
                "Frankland River" => { is_state: false, is_appellation: true },
                "Mount Barker" => { is_state: false, is_appellation: true },
                "Porongurup" => { is_state: false, is_appellation: true }
              }
            },
            "Manjimup" => { is_state: false, is_appellation: true },
            "Margaret River" => { is_state: false, is_appellation: true },
            "Pemberton" => { is_state: false, is_appellation: true }
          }
        },
        "West Australian South East Coastal" => { is_state: false, is_appellation: false }
      }
    },
    "Queensland" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Granite Belt" => { is_state: false, is_appellation: true },
        "South Burnett" => { is_state: false, is_appellation: true }
      }
    },
    "Victoria" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Central Victoria" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Bendigo" => { is_state: false, is_appellation: true },
            "Goulburn Valley" => {
              is_state: false,
              is_appellation: true,
              children: {
                "Nagambie Lakes" => { is_state: false, is_appellation: true }
              }
            },
            "Heathcote" => { is_state: false, is_appellation: true },
            "Strathbogie Ranges" => { is_state: false, is_appellation: true },
            "Upper Goulburn" => { is_state: false, is_appellation: true }
          }
        },
        "Gippsland" => { is_state: false, is_appellation: true },
        "North East Victoria" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Alpine Valleys" => { is_state: false, is_appellation: true },
            "Beechworth" => { is_state: false, is_appellation: true },
            "Glenrowan" => { is_state: false, is_appellation: true },
            "King Valley" => { is_state: false, is_appellation: true },
            "Rutherglen" => { is_state: false, is_appellation: true }
          }
        },
        "North West Victoria" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Murray Darling" => { is_state: false, is_appellation: true },
            "Swan Hill" => { is_state: false, is_appellation: true }
          }
        },
        "Port Phillip" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Geelong" => { is_state: false, is_appellation: true },
            "Macedon Ranges" => { is_state: false, is_appellation: true },
            "Mornington Peninsula" => { is_state: false, is_appellation: true },
            "Sunbury" => { is_state: false, is_appellation: true },
            "Yarra Valley" => { is_state: false, is_appellation: true }
          }
        },
        "Western Victoria" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Grampians" => {
              is_state: false,
              is_appellation: true,
              children: {
                "Great Western" => { is_state: false, is_appellation: true }
              }
            },
            "Henty" => { is_state: false, is_appellation: true },
            "Pyrenees" => { is_state: false, is_appellation: true }
          }
        }
      }
    },
    "Tasmania" => { is_state: true, is_appellation: true },
    "Northern Territory" => { is_state: true, is_appellation: false },
    "Australian Capital Territory" => { is_state: true, is_appellation: false },
    "South Eastern Australia (multi-state super-zone)" => { is_state: false, is_appellation: true }
  },
  "Brazil" => {
    "Rio Grande do Sul" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Serra Gaucha" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Vale dos Vinhedos" => { is_state: false, is_appellation: true },
            "Altos Montes" => { is_state: false, is_appellation: true },
            "Monte Belo" => { is_state: false, is_appellation: true },
            "Farroupilha" => { is_state: false, is_appellation: true },
            "Pinto Bandeira" => { is_state: false, is_appellation: true },
            "Altos de Pinto Bandeira" => { is_state: false, is_appellation: true }
          }
        },
        "Campanha Gaucha" => { is_state: false, is_appellation: true },
        "Campos de Cima da Serra" => { is_state: false, is_appellation: true }
      }
    },
    "Santa Catarina" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Serra Catarinense" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Vinhos de Altitude de Santa Catarina" => { is_state: false, is_appellation: true }
          }
        },
        "Planalto Catarinense" => { is_state: false, is_appellation: false }
      }
    },
    "Bahia" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Vale do Sao Francisco" => { is_state: false, is_appellation: true }
      }
    },
    "Pernambuco" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Vale do Sao Francisco" => { is_state: false, is_appellation: true }
      }
    },
    "Minas Gerais" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Sul de Minas" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Vinhos de Inverno Sul de Minas" => { is_state: false, is_appellation: true }
          }
        }
      }
    },
    "Parana" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Bituruna" => {
          is_state: false,
          is_appellation: false,
          children: {
            "Vinhos de Bituruna" => { is_state: false, is_appellation: true }
          }
        },
        "Norte do Parana" => { is_state: false, is_appellation: false }
      }
    },
    "Goias" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Goias" => { is_state: false, is_appellation: false }
      }
    },
    "Espirito Santo" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Espirito Santo" => { is_state: false, is_appellation: false }
      }
    },
    "Sao Paulo" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Serra da Mantiqueira" => { is_state: false, is_appellation: false },
        "Sao Roque" => { is_state: false, is_appellation: false }
      }
    }
  },
  "France" => {
    "Bordeaux" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Medoc" => { is_state: false, is_appellation: true },
        "Margaux" => { is_state: false, is_appellation: true },
        "Saint-Julien" => { is_state: false, is_appellation: true },
        "Pauillac" => { is_state: false, is_appellation: true },
        "Saint-Estephe" => { is_state: false, is_appellation: true },
        "Pessac-Leognan" => { is_state: false, is_appellation: true },
        "Graves" => { is_state: false, is_appellation: true },
        "Saint-Emilion" => { is_state: false, is_appellation: true },
        "Pomerol" => { is_state: false, is_appellation: true },
        "Sauternes" => { is_state: false, is_appellation: true },
        "Barsac" => { is_state: false, is_appellation: true },
        "Entre-Deux-Mers" => { is_state: false, is_appellation: true }
      }
    },
    "Burgundy" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Chablis" => { is_state: false, is_appellation: true },
        "Cote de Nuits" => { is_state: false, is_appellation: true },
        "Gevrey-Chambertin" => { is_state: false, is_appellation: true },
        "Vosne-Romanee" => { is_state: false, is_appellation: true },
        "Nuits-Saint-Georges" => { is_state: false, is_appellation: true },
        "Cote de Beaune" => { is_state: false, is_appellation: true },
        "Meursault" => { is_state: false, is_appellation: true },
        "Puligny-Montrachet" => { is_state: false, is_appellation: true },
        "Pommard" => { is_state: false, is_appellation: true },
        "Volnay" => { is_state: false, is_appellation: true },
        "Maconnais" => { is_state: false, is_appellation: true },
        "Beaujolais" => { is_state: false, is_appellation: true }
      }
    },
    "Champagne" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Montagne de Reims" => { is_state: false, is_appellation: false },
        "Vallee de la Marne" => { is_state: false, is_appellation: false },
        "Cote des Blancs" => { is_state: false, is_appellation: false },
        "Cote des Bar" => { is_state: false, is_appellation: false }
      }
    },
    "Rhone Valley" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Cote-Rotie" => { is_state: false, is_appellation: true },
        "Condrieu" => { is_state: false, is_appellation: true },
        "Hermitage" => { is_state: false, is_appellation: true },
        "Crozes-Hermitage" => { is_state: false, is_appellation: true },
        "Saint-Joseph" => { is_state: false, is_appellation: true },
        "Cornas" => { is_state: false, is_appellation: true },
        "Chateauneuf-du-Pape" => { is_state: false, is_appellation: true },
        "Gigondas" => { is_state: false, is_appellation: true },
        "Vacqueyras" => { is_state: false, is_appellation: true },
        "Cotes du Rhone" => { is_state: false, is_appellation: true }
      }
    },
    "Loire Valley" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Sancerre" => { is_state: false, is_appellation: true },
        "Pouilly-Fume" => { is_state: false, is_appellation: true },
        "Vouvray" => { is_state: false, is_appellation: true },
        "Chinon" => { is_state: false, is_appellation: true },
        "Bourgueil" => { is_state: false, is_appellation: true },
        "Muscadet" => { is_state: false, is_appellation: true },
        "Savennieres" => { is_state: false, is_appellation: true },
        "Saumur-Champigny" => { is_state: false, is_appellation: true }
      }
    },
    "Alsace" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Alsace Grand Cru" => { is_state: false, is_appellation: true },
        "Cremant d'Alsace" => { is_state: false, is_appellation: true }
      }
    },
    "Provence" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Cotes de Provence" => { is_state: false, is_appellation: true },
        "Bandol" => { is_state: false, is_appellation: true },
        "Cassis" => { is_state: false, is_appellation: true },
        "Bellet" => { is_state: false, is_appellation: true }
      }
    },
    "Languedoc-Roussillon" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Corbieres" => { is_state: false, is_appellation: true },
        "Minervois" => { is_state: false, is_appellation: true },
        "Faugeres" => { is_state: false, is_appellation: true },
        "Fitou" => { is_state: false, is_appellation: true },
        "Banyuls" => { is_state: false, is_appellation: true },
        "Picpoul de Pinet" => { is_state: false, is_appellation: true }
      }
    },
    "Jura" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Arbois" => { is_state: false, is_appellation: true },
        "Chateau-Chalon" => { is_state: false, is_appellation: true },
        "L'Etoile" => { is_state: false, is_appellation: true },
        "Cotes du Jura" => { is_state: false, is_appellation: true }
      }
    },
    "Savoie" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Apremont" => { is_state: false, is_appellation: true },
        "Abymes" => { is_state: false, is_appellation: true },
        "Chignin" => { is_state: false, is_appellation: true }
      }
    },
    "Southwest France" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Cahors" => { is_state: false, is_appellation: true },
        "Madiran" => { is_state: false, is_appellation: true },
        "Jurancon" => { is_state: false, is_appellation: true },
        "Bergerac" => { is_state: false, is_appellation: true }
      }
    }
  },
  "Italy" => {
    "Piedmont" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Barolo" => { is_state: false, is_appellation: true },
        "Barbaresco" => { is_state: false, is_appellation: true },
        "Barbera d'Alba" => { is_state: false, is_appellation: true },
        "Barbera d'Asti" => { is_state: false, is_appellation: true },
        "Dolcetto d'Alba" => { is_state: false, is_appellation: true },
        "Gavi" => { is_state: false, is_appellation: true },
        "Roero" => { is_state: false, is_appellation: true },
        "Asti" => { is_state: false, is_appellation: true }
      }
    },
    "Tuscany" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Chianti" => { is_state: false, is_appellation: true },
        "Chianti Classico" => { is_state: false, is_appellation: true },
        "Brunello di Montalcino" => { is_state: false, is_appellation: true },
        "Vino Nobile di Montepulciano" => { is_state: false, is_appellation: true },
        "Bolgheri" => { is_state: false, is_appellation: true },
        "Maremma" => { is_state: false, is_appellation: true }
      }
    },
    "Veneto" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Valpolicella" => { is_state: false, is_appellation: true },
        "Amarone della Valpolicella" => { is_state: false, is_appellation: true },
        "Soave" => { is_state: false, is_appellation: true },
        "Bardolino" => { is_state: false, is_appellation: true },
        "Prosecco (Conegliano Valdobbiadene)" => { is_state: false, is_appellation: true }
      }
    },
    "Friuli-Venezia Giulia" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Collio" => { is_state: false, is_appellation: true },
        "Colli Orientali del Friuli" => { is_state: false, is_appellation: true },
        "Friuli Isonzo" => { is_state: false, is_appellation: true }
      }
    },
    "Umbria" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Montefalco Sagrantino" => { is_state: false, is_appellation: true },
        "Orvieto" => { is_state: false, is_appellation: true }
      }
    },
    "Abruzzo" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Montepulciano d'Abruzzo" => { is_state: false, is_appellation: true },
        "Trebbiano d'Abruzzo" => { is_state: false, is_appellation: true }
      }
    },
    "Campania" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Taurasi" => { is_state: false, is_appellation: true },
        "Fiano di Avellino" => { is_state: false, is_appellation: true },
        "Greco di Tufo" => { is_state: false, is_appellation: true }
      }
    },
    "Puglia" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Primitivo di Manduria" => { is_state: false, is_appellation: true },
        "Salice Salentino" => { is_state: false, is_appellation: true },
        "Castel del Monte" => { is_state: false, is_appellation: true }
      }
    },
    "Sicily" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Etna" => { is_state: false, is_appellation: true },
        "Cerasuolo di Vittoria" => { is_state: false, is_appellation: true },
        "Marsala" => { is_state: false, is_appellation: true }
      }
    },
    "Lombardy" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Franciacorta" => { is_state: false, is_appellation: true },
        "Valtellina" => { is_state: false, is_appellation: true },
        "Oltrepo Pavese" => { is_state: false, is_appellation: true }
      }
    },
    "Emilia-Romagna" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Lambrusco di Sorbara" => { is_state: false, is_appellation: true },
        "Lambrusco Grasparossa" => { is_state: false, is_appellation: true }
      }
    },
    "Sardinia" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Vermentino di Gallura" => { is_state: false, is_appellation: true },
        "Cannonau di Sardegna" => { is_state: false, is_appellation: true }
      }
    }
  },
  "Spain" => {
    "Rioja" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Rioja Alta" => { is_state: false, is_appellation: true },
        "Rioja Alavesa" => { is_state: false, is_appellation: true },
        "Rioja Oriental" => { is_state: false, is_appellation: true }
      }
    },
    "Ribera del Duero" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Ribera del Duero DO" => { is_state: false, is_appellation: true }
      }
    },
    "Catalonia" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Priorat" => { is_state: false, is_appellation: true },
        "Penedes" => { is_state: false, is_appellation: true },
        "Montsant" => { is_state: false, is_appellation: true },
        "Cava" => { is_state: false, is_appellation: true }
      }
    },
    "Galicia" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Rias Baixas" => { is_state: false, is_appellation: true },
        "Ribeira Sacra" => { is_state: false, is_appellation: true },
        "Valdeorras" => { is_state: false, is_appellation: true },
        "Bierzo" => { is_state: false, is_appellation: true }
      }
    },
    "Andalusia" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Jerez-Xeres-Sherry" => { is_state: false, is_appellation: true },
        "Montilla-Moriles" => { is_state: false, is_appellation: true },
        "Malaga" => { is_state: false, is_appellation: true }
      }
    },
    "Castilla y Leon" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Rueda" => { is_state: false, is_appellation: true },
        "Toro" => { is_state: false, is_appellation: true },
        "Cigales" => { is_state: false, is_appellation: true }
      }
    },
    "Castilla-La Mancha" => {
      is_state: false,
      is_appellation: false,
      children: {
        "La Mancha" => { is_state: false, is_appellation: true },
        "Valdepenas" => { is_state: false, is_appellation: true }
      }
    },
    "Levante" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Jumilla" => { is_state: false, is_appellation: true },
        "Yecla" => { is_state: false, is_appellation: true },
        "Alicante" => { is_state: false, is_appellation: true },
        "Utiel-Requena" => { is_state: false, is_appellation: true }
      }
    },
    "Navarra" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Navarra DO" => { is_state: false, is_appellation: true }
      }
    },
    "Basque Country" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Txakoli (Getariako Txakolina)" => { is_state: false, is_appellation: true }
      }
    }
  },
  "Portugal" => {
    "Douro" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Douro DOC" => { is_state: false, is_appellation: true },
        "Porto (Port)" => { is_state: false, is_appellation: true }
      }
    },
    "Vinho Verde" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Vinho Verde DOC" => { is_state: false, is_appellation: true }
      }
    },
    "Dao" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Dao DOC" => { is_state: false, is_appellation: true }
      }
    },
    "Bairrada" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Bairrada DOC" => { is_state: false, is_appellation: true }
      }
    },
    "Alentejo" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Alentejo DOC" => { is_state: false, is_appellation: true }
      }
    },
    "Setubal Peninsula" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Setubal DOC" => { is_state: false, is_appellation: true },
        "Palmela" => { is_state: false, is_appellation: true }
      }
    },
    "Madeira" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Madeira DOC" => { is_state: false, is_appellation: true }
      }
    }
  },
  "Germany" => {
    "Mosel" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Mosel DO" => { is_state: false, is_appellation: true }
      }
    },
    "Rheingau" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Rheingau DO" => { is_state: false, is_appellation: true }
      }
    },
    "Rheinhessen" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Rheinhessen DO" => { is_state: false, is_appellation: true }
      }
    },
    "Pfalz" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Pfalz DO" => { is_state: false, is_appellation: true }
      }
    },
    "Nahe" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Nahe DO" => { is_state: false, is_appellation: true }
      }
    },
    "Baden" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Baden DO" => { is_state: false, is_appellation: true }
      }
    },
    "Franken" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Franken DO" => { is_state: false, is_appellation: true }
      }
    }
  },
  # "Austria" => {
  #   "Wachau" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Wachau DAC" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Kamptal" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Kamptal DAC" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Kremstal" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Kremstal DAC" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Burgenland" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Neusiedlersee DAC" => { is_state: false, is_appellation: true },
  #       "Mittelburgenland DAC" => { is_state: false, is_appellation: true },
  #       "Leithaberg DAC" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Weinviertel" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Weinviertel DAC" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Styria" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Sudsteiermark DAC" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # },
  # "Greece" => {
  #   "Santorini" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Santorini PDO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Macedonia" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Naoussa PDO" => { is_state: false, is_appellation: true },
  #       "Amyndeon PDO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Peloponnese" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Nemea PDO" => { is_state: false, is_appellation: true },
  #       "Mantinia PDO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Crete" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Peza PDO" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # },
  # "Hungary" => {
  #   "Tokaj" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Tokaji PDO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Eger" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Eger PDO (Egri Bikaver)" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Villany" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Villany PDO" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # },
  # "Georgia" => {
  #   "Kakheti" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Kakheti PDO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Kartli" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Kartli PDO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Imereti" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Imereti PDO" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # },
  # "Romania" => {
  #   "Dealu Mare" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Dealu Mare DOC" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Moldavia" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Cotnari DOC" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # },
  # "Croatia" => {
  #   "Istria" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Istria PDO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Dalmatia" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Peljesac" => { is_state: false, is_appellation: true },
  #       "Hvar" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # },
  "Poland" => {
    "Lubusz Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Zielona Gora" => { is_state: false, is_appellation: true },
        "Lubuskie Wine Region" => { is_state: false, is_appellation: true }
      }
    },
    "Lower Silesian Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Lower Silesia" => { is_state: false, is_appellation: true },
        "Trzebnica Hills" => { is_state: false, is_appellation: true }
      }
    },
    "Lesser Poland Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Malopolska" => { is_state: false, is_appellation: true },
        "Sandomierz Upland" => { is_state: false, is_appellation: true }
      }
    },
    "Podkarpackie Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Podkarpacie" => { is_state: false, is_appellation: true },
        "Jaslo" => { is_state: false, is_appellation: true }
      }
    },
    "Lublin Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Lubelskie" => { is_state: false, is_appellation: true }
      }
    },
    "Swietokrzyskie Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Swietokrzyskie" => { is_state: false, is_appellation: true }
      }
    },
    "Silesian Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Silesia" => { is_state: false, is_appellation: true }
      }
    },
    "Greater Poland Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Wielkopolska" => { is_state: false, is_appellation: true }
      }
    },
    "West Pomeranian Voivodeship" => {
      is_state: true,
      is_appellation: false,
      children: {
        "West Pomerania" => { is_state: false, is_appellation: true }
      }
    }
  },
  "United States" => {
    "California" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Napa Valley AVA" => { is_state: false, is_appellation: true },
        "Sonoma County AVA" => { is_state: false, is_appellation: true },
        "Russian River Valley AVA" => { is_state: false, is_appellation: true },
        "Paso Robles AVA" => { is_state: false, is_appellation: true },
        "Santa Barbara County AVA" => { is_state: false, is_appellation: true },
        "Central Coast AVA" => { is_state: false, is_appellation: true }
      }
    },
    "Oregon" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Willamette Valley AVA" => { is_state: false, is_appellation: true },
        "Dundee Hills AVA" => { is_state: false, is_appellation: true }
      }
    },
    "Washington State" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Columbia Valley AVA" => { is_state: false, is_appellation: true },
        "Walla Walla Valley AVA" => { is_state: false, is_appellation: true }
      }
    },
    "New York" => {
      is_state: true,
      is_appellation: false,
      children: {
        "Finger Lakes AVA" => { is_state: false, is_appellation: true },
        "Long Island AVA" => { is_state: false, is_appellation: true }
      }
    }
  },
  "Chile" => {
    "Central Valley" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Maipo Valley" => { is_state: false, is_appellation: true },
        "Rapel Valley" => { is_state: false, is_appellation: true },
        "Colchagua Valley" => { is_state: false, is_appellation: true },
        "Curico Valley" => { is_state: false, is_appellation: true }
      }
    },
    "Aconcagua" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Aconcagua Valley" => { is_state: false, is_appellation: true },
        "Casablanca Valley" => { is_state: false, is_appellation: true },
        "San Antonio Valley" => { is_state: false, is_appellation: true }
      }
    },
    "Southern Regions" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Maule Valley" => { is_state: false, is_appellation: true },
        "Itata Valley" => { is_state: false, is_appellation: true },
        "Bio Bio Valley" => { is_state: false, is_appellation: true }
      }
    }
  },
  "Argentina" => {
    "Mendoza" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Lujan de Cuyo" => { is_state: false, is_appellation: true },
        "Uco Valley" => { is_state: false, is_appellation: true },
        "Maipu" => { is_state: false, is_appellation: true }
      }
    },
    "Salta" => {
      is_state: false,
      is_appellation: true,
      children: {
        "Cafayate" => { is_state: false, is_appellation: true }
      }
    },
    "Patagonia" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Rio Negro" => { is_state: false, is_appellation: true }
      }
    }
  },
  "New Zealand" => {
    "Marlborough" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Marlborough GI" => { is_state: false, is_appellation: true }
      }
    },
    "Central Otago" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Central Otago GI" => { is_state: false, is_appellation: true }
      }
    },
    "Hawke's Bay" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Hawke's Bay GI" => { is_state: false, is_appellation: true }
      }
    },
    "Martinborough" => {
      is_state: false,
      is_appellation: false,
      children: {
        "Martinborough GI" => { is_state: false, is_appellation: true }
      }
    }
  }
  # "South Africa" => {
  #   "Western Cape" => {
  #     is_state: false,
  #     is_appellation: true,
  #     children: {
  #       "Stellenbosch" => { is_state: false, is_appellation: true },
  #       "Paarl" => { is_state: false, is_appellation: true },
  #       "Swartland" => { is_state: false, is_appellation: true },
  #       "Constantia" => { is_state: false, is_appellation: true },
  #       "Walker Bay" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # },
  # "Uruguay" => {
  #   "Canelones" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Canelones DO" => { is_state: false, is_appellation: true }
  #     }
  #   },
  #   "Maldonado" => {
  #     is_state: false,
  #     is_appellation: false,
  #     children: {
  #       "Maldonado DO" => { is_state: false, is_appellation: true }
  #     }
  #   }
  # }
}

def seed_regions(tree, country, parent = nil)
  tree.each do |name, payload|
    puts "\n\n\nname:#{name} ---- payload:#{payload}\n\n\n"

    is_state = payload[:is_state] || false
    is_appellation = payload[:is_appellation] || false
    children = payload[:children]
puts "\n1\n"
    region = Region.find_or_create_by!(name: name, country: country, parent: parent) do |r|
      r.is_state = is_state
      r.is_appellation = is_appellation
    end
puts "\n2\n"
    region.update!(is_state: is_state, is_appellation: is_appellation)
puts "\n3\n"
    seed_regions(children, country, region) if children.is_a?(Hash) && children.any?
puts "\n4\n"
  end
end

def seed_countries(tree)
  tree.each do |name, payload|
    puts "\n\n\nname:#{name} " #---- payload:#{payload}\n\n\n"
    country = Country.find_or_create_by!(name: name)
    puts "Seeding regions for country: #{country.name}"
    seed_regions(payload, country) if payload.is_a?(Hash) && payload.any?
  end
end

seed_countries(REGIONS)

puts "Done. Seeded #{Region.count} region records."