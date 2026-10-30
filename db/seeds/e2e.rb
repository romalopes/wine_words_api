# frozen_string_literal: true

abort "E2E seeds may only run in RAILS_ENV=e2e" unless Rails.env.e2e?

password = ENV.fetch("E2E_USER_PASSWORD", "Playwright123!")

%w[Guest Reader Reviewer Editor Admin].each { |name| Role.find_or_create_by!(name:) }
free = Subscription.find_or_create_by!(slug: "free") do |subscription|
  subscription.name = "FREE"
  subscription.active = true
  subscription.visible = true
  subscription.is_default = true
  subscription.rank = 0
  subscription.position = 0
  subscription.yearly_price_cents = 0
end

def e2e_user(email:, first_name:, role:, password:, subscription:)
  user = User.find_or_initialize_by(email:)
  user.assign_attributes(
    password:,
    password_confirmation: password,
    account_status: :active,
    subscription:,
    first_name:,
    last_name: "E2E",
    email_verified_at: Time.current
  )
  user.save!
  user.roles = [ Role.find_by!(name: role) ]
  user
end

admin = e2e_user(email: "admin.e2e@winewords.test", first_name: "Admin", role: "Admin", password:, subscription: free)
reviewer = e2e_user(email: "reviewer.e2e@winewords.test", first_name: "Reviewer", role: "Reviewer", password:, subscription: free)
e2e_user(email: "reader.e2e@winewords.test", first_name: "Reader", role: "Reader", password:, subscription: free)
e2e_user(email: "guest.e2e@winewords.test", first_name: "Guest", role: "Guest", password:, subscription: free)

country = Country.find_or_create_by!(code: "AU") do |record|
  record.name = "Australia"
  record.continent = "Oceania"
  record.is_wine_country = true
end
category = Category.find_or_create_by!(name: "E2E Reds") do |record|
  record.for_wine = true
  record.for_review = true
  record.for_article = true
end
producer = Producer.find_or_create_by!(name: "Playwright Estate") do |record|
  record.country = country
  record.email = "cellar@playwright-estate.test"
  record.producer_type = :winery
  record.active = true
end
wine = Wine.find_or_create_by!(name: "Playwright Shiraz") do |record|
  record.producer = producer
  record.color = "Red"
  record.closure = "Cork"
  record.alcohol_percentage = 14.2
  record.volume_ml = 750
end
wine.categories << category unless wine.categories.exists?(category.id)
vintage = wine.vintages.find_or_create_by!(year: 2022) { |record| record.price_cents = 4200 }

Review.find_or_create_by!(title: "Playwright published review") do |record|
  record.vintage = vintage
  record.user = reviewer
  record.score = 93
  record.status = "published"
  record.published_at = Time.current
  record.comment = "<p>Dark fruit, spice and a persistent finish.</p>"
end
Article.find_or_create_by!(title: "Playwright guide to Shiraz") do |record|
  record.user = reviewer
  record.status = "published"
  record.published_at = Time.current
  record.abstract = "A deterministic article for browser tests."
  record.body = "<p>Shiraz from the E2E cellar.</p>"
end
WinePackage.find_or_create_by!(producer:, reviewer:, created_by: admin, notes: "Playwright package") do |record|
  record.status = "arrived"
  record.source = "manual"
  record.arrived_at = Time.current
  record.review_deadline = Date.current + 30
end

puts "E2E seed ready: admin/reviewer/reader/guest, producer, wine, review, article and package"
