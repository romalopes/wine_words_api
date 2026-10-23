# frozen_string_literal: true

# Canonical, non-destructive Wine Words seed entry point.
# rails db:seed
#

# bundle exec rails runner db/seeds/destroy_all.rb
#  CONFIRM=DESTROY bin/rails runner db/seeds/destroy_all.rb
# load Rails.root.join('db', 'seeds', 'destroy_all.rb').to_s

# bundle exec rails runner db/seeds/reset_pk_sequences.rb
load Rails.root.join('db', 'seeds', 'reset_pk_sequences.rb').to_s

# bundle exec rails runner db/seeds/roles.rb
load Rails.root.join('db', 'seeds', 'roles.rb').to_s

# bundle exec rails runner db/seeds/subscriptions.rb
load Rails.root.join('db', 'seeds', 'subscriptions.rb').to_s
puts "  - #{Subscription.count} subscriptions"


# bundle exec rails runner db/seeds/create_three_basic_users.rb
load Rails.root.join('db', 'seeds', 'create_three_basic_users.rb').to_s
puts "  - #{User.count} users"

# bundle exec rails runner db/seeds/countries.rb
load Rails.root.join('db', 'seeds', 'countries.rb').to_s
puts "  - #{Country.count} countries"

# bundle exec rails runner db/seeds/regions.rb
load Rails.root.join('db', 'seeds', 'regions.rb').to_s
puts "  - #{Region.count} regions"

# bundle exec rails runner db/seeds/grapes.rb
load Rails.root.join('db', 'seeds', 'grapes.rb').to_s
puts "  - #{Grape.count} grapes"

# Wine profiles and their taste scores are maintained in one consolidated,
# idempotent source. It also upserts the six taste parameters, including their
# server-authoritative five-level labels. Legacy profile seed variants remain
# as compatibility wrappers but must not be loaded from here.
#  bundle exec rails runner db/seeds/wine_profiles/wine_profiles_seed_consolidated.rb
load Rails.root.join('db', 'seeds', 'wine_profiles', 'wine_profiles_seed_consolidated.rb').to_s
puts "Seeds created successfully!"
puts "  - #{TasteParameter.count} taste parameters"
puts "  - #{WineProfile.count} wine profiles"
puts "  - #{WineProfileTasteParameter.count} profile taste parameters"
puts "  - #{WineTasteParameter.count} wine taste parameters"


# bundle exec rails runner db/seeds/producers.rb
load Rails.root.join('db', 'seeds', 'producers.rb').to_s
puts "  - #{Producer.count} producers"

#  bundle exec rails runner db/seeds/producers_ray_jordan.rb
load Rails.root.join('db', 'seeds', 'producers_ray_jordan.rb').to_s
puts "  - #{Producer.count} producers"

#  bundle exec rails runner db/seeds/substack_reviews_articles_seed.rb
load Rails.root.join('db', 'seeds', 'substack_reviews_articles_seed.rb').to_s
puts "  - #{Review.count} reviews"
puts "  - #{Article.count} articles"
puts "  - #{Wine.count} articles"

puts "\n\n\n\n\n\nSeeds created successfully!"

