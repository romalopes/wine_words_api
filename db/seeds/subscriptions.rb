# db/seeds/subscriptions.rb
#
# Seeds the subscription plans and the subscription-feature catalogue.
# Loaded from db/seeds.rb (or run directly: rails runner db/seeds/subscriptions.rb).
#
# Idempotent: find_or_create_by on slug/name, and per-subscription feature
# links are upserted without duplicating.

feature_catalogue = [
  { slug: "full-archive-access", name: "Full access to all wine reviews and tasting notes" },
  { slug: "unlimited-reviews", name: "Unlimited access to reviews and scores" },
  { slug: "consumer-flexibility", name: "Includes every Consumer subscription feature" },
  { slug: "trade-benefits", name: "Includes every Trade subscription feature" },
  { slug: "distributor-benefits", name: "Includes every Distributor subscription feature" },
  { slug: "retail-benefits", name: "Includes every Retail subscription feature" },
  { slug: "republishing-rights-sme", name: "Republishing rights for small and medium enterprises" },
  { slug: "republishing-rights-large", name: "Republishing rights for large-scale trade & media" },
  { slug: "priority-support", name: "Priority email support" },
  { slug: "api-access", name: "API access for your point-of-sale system" },
]

features = feature_catalogue.map do |f|
  SubscriptionFeature.find_or_create_by!(slug: f[:slug]) { |sf| sf.name = f[:name] }
end

by_slug = features.index_by(&:slug)

def link_features(subscription, feature_slugs)
  subscription.subscription_subscription_features.destroy_all
  feature_slugs.each_with_index do |slug, index|
    subscription.subscription_subscription_features.find_or_create_by!(
      subscription_feature: SubscriptionFeature.find_by!(slug: slug)
    ) { |ssf| ssf.position = index }
  end
end

plans = [
  {
    slug: "free", name: "FREE", popular: false, visible: true, active: true,
    is_default: true, position: 0, monthly_price_cents: nil, yearly_price_cents: 0,
    description: "Start exploring with free access.",
    features: []
  },
  {
    slug: "consumer", name: "Consumer", popular: true, visible: true, active: true,
    is_default: false, position: 1, monthly_price_cents: nil, yearly_price_cents: 7_00,
    description: "For the everyday wine lover.",
    features: ["full-archive-access"]
  },
  {
    slug: "trade", name: "Trade", popular: false, visible: true, active: true,
    is_default: false, position: 2, monthly_price_cents: nil, yearly_price_cents: 24_000,
    description: "For hospitality and trade professionals.",
    features: ["consumer-flexibility", "trade-benefits", "priority-support"]
  },
  {
    slug: "distributor", name: "Distributor", popular: false, visible: true, active: true,
    is_default: false, position: 3, monthly_price_cents: nil, yearly_price_cents: 40_000,
    description: "For distributors and national trade.",
    features: ["distributor-benefits", "republishing-rights-sme", "api-access"]
  },
  {
    slug: "retail", name: "Retail", popular: false, visible: true, active: true,
    is_default: false, position: 4, monthly_price_cents: nil, yearly_price_cents: 60_000,
    description: "For retailers and large-scale operators.",
    features: ["retail-benefits", "republishing-rights-large", "priority-support", "api-access"]
  }
]

plans.each do |plan|
  sub = Subscription.find_or_initialize_by(slug: plan[:slug])
  sub.assign_attributes(
    name: plan[:name], popular: plan[:popular], visible: plan[:visible],
    active: plan[:active], is_default: plan[:is_default], position: plan[:position],
    monthly_price_cents: plan[:monthly_price_cents],
    yearly_price_cents: plan[:yearly_price_cents],
    description: plan[:description]
  )
  sub.save!
  link_features(sub, plan[:features])
end

puts "Seeded #{Subscription.count} subscription plans and #{SubscriptionFeature.count} features."