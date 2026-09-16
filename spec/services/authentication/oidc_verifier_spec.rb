require "rails_helper"
require "jwt"
require "openssl"

# These specs exercise the *real* token verification path: signatures are
# checked against a locally generated RSA key that stands in for the provider's
# published JWKS. Nothing about the token is trusted without those checks, so
# this is where signature/issuer/audience/expiry/algorithm enforcement is
# proven rather than assumed.
RSpec.describe "Authentication OIDC verifiers", type: :model do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:other_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:kid) { "test-key-1" }

  # The document the provider would serve at its JWKS URL.
  def jwks_document(signing_key = key, key_id: kid)
    jwk = JWT::JWK.new(signing_key, { kid: key_id, use: "sig", alg: "RS256" })
    { "keys" => [ jwk.export ] }
  end

  def encode(claims, signing_key: key, key_id: kid)
    JWT.encode(claims, signing_key, "RS256", { kid: key_id })
  end

  def stub_jwks(signing_key = key, key_id: kid)
    allow(Authentication::HttpClient).to receive(:get_json)
      .and_return(jwks_document(signing_key, key_id: key_id))
  end

  describe Authentication::Google do
    subject(:verifier) { described_class }

    around do |example|
      with_env("GOOGLE_CLIENT_ID" => "google-client-id") { example.run }
    end

    def google_token(overrides = {}, signing_key: key, key_id: kid)
      encode({
        "iss" => "https://accounts.google.com",
        "aud" => "google-client-id",
        "sub" => "google-sub-123",
        "email" => "John@Example.com",
        "email_verified" => true,
        "name" => "John Doe",
        "exp" => 1.hour.from_now.to_i,
        "iat" => Time.current.to_i
      }.merge(overrides), signing_key: signing_key, key_id: key_id)
    end

    it "accepts a valid credential and uses sub as the identity key" do
      stub_jwks
      claims = verifier.verify(google_token)

      expect(claims.provider).to eq("google")
      expect(claims.provider_uid).to eq("google-sub-123")
      expect(claims.email).to eq("john@example.com")
      expect(claims.email_verified?).to be true
    end

    it "is configured only when the client id is present" do
      expect(verifier.configured?).to be true
      with_env("GOOGLE_CLIENT_ID" => nil) do
        expect(verifier.configured?).to be false
      end
    end

    it "raises a safe error when the app is not configured" do
      with_env("GOOGLE_CLIENT_ID" => nil) do
        expect { verifier.verify(google_token) }
          .to raise_error(Authentication::Error) { |e|
            expect(e.code).to eq(:provider_not_configured)
            expect(e.status).to eq(:service_unavailable)
          }
      end
    end

    it "rejects a token signed by a key the provider does not publish" do
      stub_jwks
      expect { verifier.verify(google_token(signing_key: other_key)) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects an expired token" do
      stub_jwks
      expect { verifier.verify(google_token({ "exp" => 10.minutes.ago.to_i })) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a token issued for a different audience" do
      stub_jwks
      expect { verifier.verify(google_token({ "aud" => "someone-elses-client-id" })) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a token from an unexpected issuer" do
      stub_jwks
      expect { verifier.verify(google_token({ "iss" => "https://evil.example.com" })) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects an unsigned token" do
      stub_jwks
      unsigned = JWT.encode({ "sub" => "attacker", "aud" => "google-client-id",
                              "iss" => "https://accounts.google.com",
                              "exp" => 1.hour.from_now.to_i }, nil, "none")
      expect { verifier.verify(unsigned) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects an unknown key id rather than falling back to a default key" do
      stub_jwks
      expect { verifier.verify(google_token(key_id: "rotated-away")) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a blank credential" do
      stub_jwks
      expect { verifier.verify("") }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "treats an unverified email as unverified" do
      stub_jwks
      claims = verifier.verify(google_token({ "email_verified" => false }))
      expect(claims.email_verified?).to be false
    end

    it "normalises a string email_verified literal" do
      stub_jwks
      expect(verifier.verify(google_token({ "email_verified" => "true" })).email_verified?).to be true
    end
  end
end