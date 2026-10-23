# frozen_string_literal: true

# Canonical, non-destructive Wine Words seed entry point.
#
# Wine profiles and their taste scores are maintained in one consolidated,
# idempotent source. It also upserts the six taste parameters, including their
# server-authoritative five-level labels. Legacy profile seed variants remain
# as compatibility wrappers but must not be loaded from here.
load Rails.root.join('db', 'seeds', 'wine_profiles', 'wine_profiles_seed_consolidated.rb').to_s

puts "Seeds created successfully!"
puts "  - #{TasteParameter.count} taste parameters"
puts "  - #{WineProfile.count} wine profiles"
puts "  - #{WineProfileTasteParameter.count} profile taste parameters"
puts "  - #{Wine.count} wines"
puts "  - #{WineTasteParameter.count} wine taste parameters"
puts "  - #{Vintage.count} vintages"
