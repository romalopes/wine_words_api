require "rails_helper"

RSpec.describe "Api::V1::Users account administration", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { user_with_role("Admin") }
  let(:editor) { user_with_role("Editor") }
  let(:target) do
    User.create!(
      first_name: "Original",
      last_name: "Name",
      email: "target-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
  end

  def user_with_role(role_name)
    user = User.create!(
      email: "#{role_name.downcase}-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )
    user.roles << Role.find_or_create_by!(name: role_name)
    user
  end

  describe "GET /api/v1/users/:id" do
    it "includes the user's personal information and address" do
      country = Country.create!(name: "Profileland", code: "PF")
      target.account.update!(phone: "+1 555 0100", date_of_birth: "1990-05-01")
      target.account.create_account_address!(city: "Portland", country: country)
      sign_in admin

      get "/api/v1/users/#{target.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["account"]).to include(
        "first_name" => "Original",
        "last_name" => "Name",
        "phone" => "+1 555 0100",
        "date_of_birth" => "1990-05-01"
      )
      expect(response.parsed_body.dig("account", "address")).to include(
        "city" => "Portland",
        "country_id" => country.id
      )
    end

    it "does not expose personal information to non-admin catalogue managers" do
      sign_in editor

      get "/api/v1/users/#{target.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).not_to have_key("account")
    end
  end

  describe "PATCH /api/v1/users/:id/account" do
    it "allows an admin to update personal information and address" do
      country = Country.create!(name: "Adminland", code: "AD")
      sign_in admin

      patch "/api/v1/users/#{target.id}/account", params: {
        first_name: "Updated",
        last_name: "Person",
        phone: "+1 555 0199",
        date_of_birth: "1988-03-12",
        address: {
          street_address: "12 Cellar Road",
          city: "Napa",
          state: "CA",
          postal_code: "94558",
          country_id: country.id
        }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(target.reload.display_name).to eq("Updated Person")
      expect(target.account.phone).to eq("+1 555 0199")
      expect(target.account.account_address).to have_attributes(
        city: "Napa",
        country_id: country.id
      )
    end

    it "rejects updates from non-admin catalogue managers" do
      sign_in editor

      patch "/api/v1/users/#{target.id}/account",
            params: { first_name: "Forbidden", last_name: "Change" },
            as: :json

      expect(response).to have_http_status(:forbidden)
      expect(target.reload.first_name).to eq("Original")
    end

    it "returns validation errors without changing the account" do
      sign_in admin

      patch "/api/v1/users/#{target.id}/account",
            params: { first_name: " ", last_name: "Name" },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(target.reload.first_name).to eq("Original")
    end
  end
end