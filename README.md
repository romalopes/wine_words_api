---

# Set up of the database.

load Rails.root.join("db/seeds/countries.rb")
load Rails.root.join("db/seeds/regions.rb")
load Rails.root.join("db/seeds/grapes.rb")
load Rails.root.join("db/seeds/subscriptions.rb")

# For development

load Rails.root.join("db/seeds/producers.rb")
load Rails.root.join("db/seeds/wines.rb")

load Rails.root.join("db/seeds/articles_and_reviews.rb")

lsof -i :3000
