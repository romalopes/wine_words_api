require "rails_helper"

# "Submitted as a guest, then logged in": the submission has no owner until the
# account that owns the contact email claims it. Anyone else — including a
# logged-in user with a different email — must keep getting the no-disclosure
# 404, exactly like GET /trade/packages/:id.
RSpec.describe "Api::V1::Trade::Packages#claim_by_email", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:owner) do
    User.create!(first_name: "Ana", email: "ana@bodega.example", password: "password123")
  end
  let(:other) do
    User.create!(first_name: "Bea", email: "bea@other.example", password: "password123")
  end

  let(:package) do
    WinePackage.create!(
      source: "trade_submission",
      status: "editorial_pending",
      contact_snapshot: {
        "company_name" => "Bodega Ejemplo",
        "contact_name" => "Ana Ruiz",
        "email" => "ana@bodega.example"
      }
    )
  end

  before { sign_in owner }

  it "claims an unclaimed submission whose contact email matches the account" do
    post "/api/v1/trade/packages/#{package.id}/claim", as: :json

    expect(response).to have_http_status(:ok)
    expect(package.reload.submitter_id).to eq(owner.id)
    body = JSON.parse(response.body)
    expect(body["id"]).to eq(package.id)
    expect(body["items"]).to be_an(Array)
  end

  it "records a single package_claimed event across repeated claims" do
    post "/api/v1/trade/packages/#{package.id}/claim", as: :json
    post "/api/v1/trade/packages/#{package.id}/claim", as: :json

    expect(
      package.reload.wine_package_events.where(event_type: "package_claimed").count
    ).to eq(1)
  end

  it "is idempotent when the package is already claimed by the same user" do
    package.update!(submitter: owner)

    post "/api/v1/trade/packages/#{package.id}/claim", as: :json

    expect(response).to have_http_status(:ok)
    expect(package.reload.submitter_id).to eq(owner.id)
  end

  it "hides a submission whose contact email belongs to another account" do
    mismatched = WinePackage.create!(
      source: "trade_submission",
      status: "editorial_pending",
      contact_snapshot: {
        "company_name" => "Other Co",
        "contact_name" => "Bea Doe",
        "email" => "bea@other.example"
      }
    )

    post "/api/v1/trade/packages/#{mismatched.id}/claim", as: :json

    expect(response).to have_http_status(:not_found)
    expect(mismatched.reload.submitter_id).to be_nil
  end

  it "returns 404 for packages that are not trade submissions" do
    editorial = WinePackage.create!(
      source: "manual",
      status: "draft",
      producer: Producer.create!(name: "Penfolds")
    )

    post "/api/v1/trade/packages/#{editorial.id}/claim", as: :json

    expect(response).to have_http_status(:not_found)
  end

  it "never exposes another user's claimed package" do
    package.update!(submitter: other)

    post "/api/v1/trade/packages/#{package.id}/claim", as: :json

    expect(response).to have_http_status(:not_found)
    expect(package.reload.submitter_id).to eq(other.id)
  end
end
