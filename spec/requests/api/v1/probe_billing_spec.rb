require "rails_helper"
require "devise"

RSpec.describe "PROBE billing signed-in", type: :request do
  include Devise::Test::IntegrationHelpers

  it "probes the billing endpoint as admin" do
    admin = User.create!(first_name: "ProbeAdmin", email: "probe-admin@example.com", password: "password123")
    admin.roles << Role.find_or_create_by!(name: "Admin")
    pkg = WinePackage.create!(
      source: "trade_submission",
      status: "editorial_pending",
      contact_snapshot: { "contact_name" => "Probe", "email" => "probe@example.com" },
      wine_package_items_attributes: [
        { proposed_wine_name: "Probe Wine", proposed_vintage_year: 2023, quantity: 2 }
      ]
    )
    policy = WinePackagePolicy.new(admin, pkg)
    puts "POLICY view_billing?: #{policy.view_billing?}"
    sign_in admin
    get "/api/v1/wine_packages/#{pkg.id}/billing"
    puts "BILLING STATUS: #{response.status}"
    puts "BILLING BODY: #{response.body.first(400)}"
  end
end
