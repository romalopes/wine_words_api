require "rails_helper"

# Facebook Login: unlike the OIDC providers there is no ID token to verify, so
# the access token is validated against Meta's Graph API. These specs cover
# both halves — the `debug_token` check that proves the token is valid and was
# issued to *our* app, and the `/me` read that establishes identity — plus the
# deliberate policy that a Facebook address is never treated as verified.
RSpec.describe Authentication::Facebook, type: :model do
  let(:app_id) { "fb-app-123" }
  let(:app_secret) { "fb-app-secret" }
  let(:uid) { "fb-uid-1" }

  around do |example|
    with_env("FACEBOOK_APP_ID" => app_id, "FACEBOOK_APP_SECRET" => app_secret) { example.run }
  end

  def debug_payload(overrides = {})
    { "app_id" => app_id, "is_valid" => true, "user_id" => uid,
      "expires_at" => 1.hour.from_now.to_i }.merge(overrides)
  end

  def profile_payload(overrides = {})
    { "id" => uid, "name" => "Fb Person", "email" => "Fb.Person@Example.com" }.merge(overrides)
  end

  # Stubs the two Graph calls the verifier makes and captures the params so the
  # specs can prove which token/app credentials were sent.
  def stub_graph(debug: debug_payload, profile: profile_payload)
    calls = []
    allow(Authentication::HttpClient).to receive(:get_json) do |url, **kwargs|
      calls << [ url, kwargs[:params] ]
      url.include?("debug_token") ? { "data" => debug } : profile
    end
    calls
  end

  describe ".configured?" do
    it "is configured when both the app id and secret are present" do
      expect(described_class.configured?).to be true
    end

    it "is not configured without an app secret" do
      with_env("FACEBOOK_APP_SECRET" => nil) do
        expect(described_class.configured?).to be false
      end
    end

    it "is not configured without an app id" do
      with_env("FACEBOOK_APP_ID" => nil) do
        expect(described_class.configured?).to be false
      end
    end
  end

  describe ".verify" do
    it "accepts a valid credential and uses the app-scoped id as the identity key" do
      stub_graph
      claims = described_class.verify("user-access-token")

      expect(claims.provider).to eq("facebook")
      expect(claims.provider_uid).to eq(uid)
      expect(claims.email).to eq("fb.person@example.com")
      expect(claims.name).to eq("Fb Person")
    end

    it "never treats a Facebook address as verified" do
      stub_graph
      # Meta gives no per-token verification signal, so auto-linking by email
      # must not happen (see Authentication::SocialLogin).
      expect(described_class.verify("user-access-token").email_verified?).to be false
    end

    it "still resolves the identity when Facebook returns no email" do
      stub_graph(profile: profile_payload("email" => nil))
      claims = described_class.verify("user-access-token")

      expect(claims.provider_uid).to eq(uid)
      expect(claims.email).to be_nil
    end

    it "validates the token with the app access token, which is never returned to the caller" do
      calls = stub_graph
      described_class.verify("user-access-token")

      debug_params = calls.find { |url, _| url.include?("debug_token") }.last
      expect(debug_params[:input_token]).to eq("user-access-token")
      expect(debug_params[:access_token]).to eq("#{app_id}|#{app_secret}")
    end

    it "rejects a token Meta reports as invalid or expired" do
      stub_graph(debug: debug_payload("is_valid" => false))
      expect { described_class.verify("expired-token") }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a valid token that was issued to a different application" do
      stub_graph(debug: debug_payload("app_id" => "someone-elses-app"))
      expect { described_class.verify("foreign-token") }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a profile whose id disagrees with the validated token" do
      stub_graph(profile: profile_payload("id" => "a-different-user"))
      expect { described_class.verify("user-access-token") }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a blank credential without calling the provider" do
      expect(Authentication::HttpClient).not_to receive(:get_json)
      expect { described_class.verify("") }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "raises a safe error when the app is not configured" do
      with_env("FACEBOOK_APP_SECRET" => nil) do
        expect(Authentication::HttpClient).not_to receive(:get_json)
        expect { described_class.verify("user-access-token") }
          .to raise_error(Authentication::Error) { |e|
            expect(e.code).to eq(:provider_not_configured)
            expect(e.status).to eq(:service_unavailable)
          }
      end
    end

    it "raises a safe error when Meta rejects the request" do
      allow(Authentication::HttpClient).to receive(:get_json)
        .and_raise(Authentication::Error.new("Could not reach the identity provider.",
                                             code: :provider_unavailable, status: :service_unavailable))
      expect { described_class.verify("user-access-token") }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:provider_unavailable) }
    end
  end
end