require "rails_helper"

# Request specs for the server-rendered account settings page
# (Web::AccountsController) — rendering, profile update and password change.
RSpec.describe "Web::Accounts", type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.create!(user_name: "webby", email: "webby@example.com", password: "password123")
  end

  before { sign_in user }

  it "renders the account settings page with the user's username" do
    get account_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Account settings")
    expect(response.body).to include("webby")
    expect(response.body).to include("Security")
  end

  it "updates the username, personal info and address" do
    patch account_path, params: {
      user_name: "webby2",
      account: {
        first_name: "Web",
        last_name: "By",
        phone: "+61 400 000 000",
        date_of_birth: "1991-03-03",
        account_address_attributes: {
          street_address: "2 Grape Ln",
          city: "Adelaide",
          state: "SA",
          postal_code: "5001"
        }
      }
    }

    expect(response).to redirect_to(account_path)
    expect(user.reload.user_name).to eq("webby2")
    expect(user.account.first_name).to eq("Web")
    expect(user.account.account_address.city).to eq("Adelaide")
  end

  it "rejects a duplicate username and re-renders the form" do
    User.create!(user_name: "taken", email: "taken-web@example.com", password: "password123")
    patch account_path, params: { user_name: "taken", account: {} }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("already been taken")
  end

  it "changes the password with the correct current password" do
    patch account_password_path, params: {
      current_password: "password123",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    expect(response).to redirect_to(account_path)
    expect(user.reload.valid_password?("newpassword123")).to be(true)
  end

  it "refuses a password change with the wrong current password" do
    patch account_password_path, params: {
      current_password: "wrong",
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(user.reload.valid_password?("password123")).to be(true)
  end
end
