require "rails_helper"

# Request specs for Api::V1::PasswordsController — the JSON "forgot password"
# flow. Covers requesting a reset (POST) and performing the reset (PATCH),
# including the JWT issued on a successful reset.
RSpec.describe "Api::V1::Passwords", type: :request do
  let!(:user) do
    User.create!(name: "Roma", email: "roma@example.com", password: "oldpassword123")
  end

  describe "POST /api/v1/auth/password" do
    it "returns 200 with a neutral message" do
      post "/api/v1/auth/password", params: { user: { email: user.email } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to match(/instructions/i)
    end

    it "generates a reset token for the user" do
      expect {
        post "/api/v1/auth/password", params: { user: { email: user.email } }, as: :json
      }.to change { user.reload.reset_password_token.present? }.to(true)
    end

    it "does not reveal whether the email exists" do
      post "/api/v1/auth/password", params: { user: { email: "nobody@example.com" } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to match(/instructions/i)
    end
  end

  describe "PATCH /api/v1/auth/password" do
    let(:raw_token) do
      Devise.token_generator.generate(User, :reset_password_token).first
    end

    before do
      user.update!(
        reset_password_token: Devise.token_generator.digest(User, :reset_password_token, raw_token),
        reset_password_sent_at: Time.current
      )
    end

    it "resets the password and returns the user" do
      patch "/api/v1/auth/password",
            params: {
              user: {
                reset_password_token: raw_token,
                password: "newpassword123",
                password_confirmation: "newpassword123"
              }
            },
            as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["user"]["email"]).to eq(user.email)
      expect(user.reload.valid_password?("newpassword123")).to be(true)
    end

    it "issues a JWT (Authorization header) on success" do
      patch "/api/v1/auth/password",
            params: {
              user: {
                reset_password_token: raw_token,
                password: "newpassword123",
                password_confirmation: "newpassword123"
              }
            },
            as: :json

      expect(response.headers["Authorization"]).to be_present
    end

    it "rejects an invalid token with 422" do
      patch "/api/v1/auth/password",
            params: {
              user: {
                reset_password_token: "bogus-token",
                password: "newpassword123",
                password_confirmation: "newpassword123"
              }
            },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to be_present
    end

    it "rejects a mismatched password confirmation with 422" do
      patch "/api/v1/auth/password",
            params: {
              user: {
                reset_password_token: raw_token,
                password: "newpassword123",
                password_confirmation: "different"
              }
            },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end