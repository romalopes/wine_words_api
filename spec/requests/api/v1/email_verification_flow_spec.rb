# End-to-end email-verification flow (REQUIRE_EMAIL_VERIFICATION=true):
# sign-up sends the email without issuing a session, sign-in of a pending user
# is refused with the deadline, an expired user is locked, the token click
# verifies, and a resend opens a fresh window. Feature-off behaviour (a normal
# session on sign-up) is asserted at the end so a config regression is loud.
require "rails_helper"

RSpec.describe "Email verification flow", type: :request do
  let(:password) { "password123" }
  let(:email) { "verify-flow-#{SecureRandom.hex(4)}@example.com" }
  let(:sign_up_params) do
    { user: { user_name: "Verify Flow #{SecureRandom.hex(2)}", email: email,
              password: password, password_confirmation: password } }
  end

  def with_verification_required
    allow(EmailVerification).to receive(:require?).and_return(true)
    allow(EmailVerification).to receive(:auto_send_on_signup?).and_return(true)
    yield
  end

  def sign_up!
    post "/api/v1/auth/sign_up", params: sign_up_params, as: :json
  end

  def sign_in!
    post "/api/v1/auth/sign_in", params: { user: { email: email, password: password } }, as: :json
  end

  def token_from_last_mail
    mail = ActionMailer::Base.deliveries.last
    source = mail.multipart? ? [mail.text_part&.decoded, mail.html_part&.decoded].join : mail.body.to_s
    source[/token=([A-Za-z0-9_\-]+)/, 1]
  end

  before { ActionMailer::Base.deliveries.clear }

  context "when verification is required" do
    it "sends a verification email on sign-up and issues NO session" do
      with_verification_required do
        expect { sign_up! }.to change(ActionMailer::Base.deliveries, :count).by(1)
      end

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["email_verification"]["email_verification_pending"]).to be(true)
      expect(body["email_verification"]["email_verification_deadline"]).to be_present
      expect(response.headers["Authorization"]).to be_nil

      user = User.find_by(email: email)
      expect(user.email_verification_pending?).to be(true)
      expect(user.email_verification_expires_at).to be_within(5.seconds).of(24.hours.from_now)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([email])
      expect(mail.subject).to include("Verify your email")
    end

    it "refuses sign-in for a pending user with 403 + deadline payload" do
      with_verification_required do
        sign_up!
        sign_in!
      end

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["email_verification_pending"]).to be(true)
      expect(body["email_verification_deadline"]).to be_present
      # The JWT Devise put on the sign-in response must not yield a usable
      # session: /me answers with 401 (revoked) or 403 (verification lock),
      # never 200.
      jwt = response.headers["Authorization"]&.sub(/^Bearer\s+/i, "")
      expect(jwt).to be_present
      get "/api/v1/me", headers: { "Authorization" => "Bearer #{jwt}" }
      expect(response.status).not_to eq(200)
      expect(JSON.parse(response.body)["user"]).to be_nil
    end

    it "locks the account once the verification window has passed" do
      with_verification_required do
        sign_up!
        User.find_by(email: email).update_column(:email_verification_sent_at, 48.hours.ago)

        sign_in!
        expect(response).to have_http_status(:forbidden)
        body = JSON.parse(response.body)
        expect(body["email_verification_expired"]).to be(true)
        expect(body["error"]).to match(/expired|locked/)

        # The stale link no longer verifies either.
        get "/api/v1/email-verifications/#{token_from_last_mail}"
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it "verifies the account when the link is clicked, unlocking sign-in" do
      with_verification_required do
        sign_up!
        raw_token = token_from_last_mail
        expect(raw_token).to be_present

        get "/api/v1/email-verifications/#{raw_token}"
        expect(response).to have_http_status(:ok)

        user = User.find_by(email: email)
        expect(user.email_verified?).to be(true)
        expect(user.email_verification_pending?).to be(false)

        sign_in!
        expect(response).to have_http_status(:ok)
        expect(response.headers["Authorization"]).to be_present
      end
    end

    it "returns a generic error for an unknown token" do
      with_verification_required do
        get "/api/v1/email-verifications/not-a-real-token"
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to be_present
      end
    end

    it "resends on request, enforces the cooldown, and the new token verifies" do
      with_verification_required do
        sign_up!
        expect(ActionMailer::Base.deliveries.count).to eq(1)

        # Immediately again: inside the 1-minute cooldown, no new email.
        post "/api/v1/email-verifications/resend", params: { email_address: email }, as: :json
        expect(response).to have_http_status(:accepted)
        expect(ActionMailer::Base.deliveries.count).to eq(1)

        # Outside the cooldown: a fresh email with a fresh (working) token.
        User.find_by(email: email).update_column(:email_verification_sent_at, 2.minutes.ago)
        post "/api/v1/email-verifications/resend", params: { email_address: email }, as: :json
        expect(ActionMailer::Base.deliveries.count).to eq(2)

        get "/api/v1/email-verifications/#{token_from_last_mail}"
        expect(response).to have_http_status(:ok)
        expect(User.find_by(email: email).email_verified?).to be(true)
      end
    end
  end

  context "when verification is not required (default)" do
    it "issues a normal session on sign-up and sends no email" do
      allow(EmailVerification).to receive(:require?).and_return(false)

      expect { sign_up! }.not_to change(ActionMailer::Base.deliveries, :count)
      expect(response).to have_http_status(:created)
      expect(response.headers["Authorization"]).to be_present
      expect(JSON.parse(response.body)["email_verification"]).to be_nil
    end
  end
end
