# Run with: bin/rails runner db/seeds/create_three_basic_users.rb
# Prerequisite: bin/rails runner db/seeds/subscriptions.rb
# SEED_PASSWORD in .env.development supplies the same password for all NEW users.
# Existing passwords are preserved. This seed does not send emails,
# verify email addresses, or link Google identities.

seed_password = ENV.fetch("SEED_PASSWORD")
raise "SEED_PASSWORD must not be blank" if seed_password.blank?

users = [
  { first_name: "Anderson", email: "romalopes@yahoo.com.br",
    roles: ["Admin"], subscription: "free" },
  { first_name: "AndersonGoogle", email: "romalopes@gmail.com",
    roles: ["Reader"], subscription: "consumer" },
  { first_name: "Kasia", email: "kasia@mywineadviser.com.au",
    roles: ["Reviewer", "Editor"], subscription: "free" }
]

User.transaction do
  plans = Subscription.where(slug: users.map { |attributes| attributes[:subscription] }.uniq).index_by(&:slug)
  missing = %w[free consumer] - plans.keys
  if missing.any?
    raise "Missing subscription plans: #{missing.join(', ')}. Run bin/rails runner db/seeds/subscriptions.rb first."
  end

  users.each do |attributes|
    user = User.find_or_initialize_by(email: attributes[:email])
    if user.new_record?
      user.password = seed_password
      user.password_confirmation = user.password
    end
    user.first_name = attributes[:first_name]
    user.save!

    plan = plans.fetch(attributes[:subscription])
    unless user.subscription_id == plan.id && user.user_subscriptions.current.exists?(subscription_id: plan.id)
      user.apply_subscription!(plan, allow_downgrade: true)
    end

    # Apply after subscription callbacks so the final role set matches the
    # requested roles, including privileged users on the Free plan.
    user.roles = attributes[:roles].map { |name| Role.find_or_create_by!(name: name) }
  end
end

puts "Seeded Anderson (Admin / Free), AndersonGoogle (Reader / Consumer), and Kasia (Reviewer, Editor / Free)."
