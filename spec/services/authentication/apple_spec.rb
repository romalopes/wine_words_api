require "rails_helper"
require "jwt"
require "openssl"
require "digest"

# Sign in with Apple: real Apple-style ID token verification against a locally
# generated RSA key standing in for Apple's published JWKS, plus the two Apple
# quirks that matter most — the SHA-256-hashed nonce and the private relay
# email address.
RSpec.describe Authentication::Apple, type: :model do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:other_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:kid) { "apple-test-key" }
  let(:client_id) { "com.wineprediction.web" }
  # The raw nonce React generates and sends to Apple.
  let(:raw_nonce) { "raw-nonce-from-the-spa" }
  # Apple places the *digest* in the identity token, never the raw value.
  let(:nonce_digest) { Digest::SHA256.hexdigest(raw_nonce) }

  around do |example|
    with_env("APPLE_CLIENT_ID" => client_id) { example.run }
  end

  def jwks_document(signing_key = key, key_id: kid)
    jwk = JWT::JWK.new(signing_key, { kid: key_id, use: "sig", alg: "RS256" })
    { "keys" => [ jwk.export ] }
  end

  def stub_jwks(signing_key = key, key_id: kid)
    allow(Authentication::HttpClient).to receive(:get_json)
      .and_return(jwks_document(signing_key, key_id: key_id))
  end

  def apple_token(overrides = {}, signing_key: key, key_id: kid)
    JWT.encode(
      {
        "iss" => "https://appleid.apple.com",
        "aud" => client_id,
        "sub" => "apple-sub-001",
        "email" => "Jane@Example.com",
        "email_verified" => "true",
        "nonce" => nonce_digest,
        "exp" => 1.hour.from_now.to_i,
        "iat" => Time.current.to_i
      }.merge(overrides),
      signing_key, "RS256", { kid: key_id }
    )
  end

  describe ".configured?" do
    it "is configured when the Services ID is present" do
      expect(described_class.configured?).to be true
    end

    it "is not configured without a Services ID" do
      with_env("APPLE_CLIENT_ID" => nil) do
        expect(described_class.configured?).to be false
      end
    end
  end

  describe ".verify" do
    it "accepts a valid credential and uses sub as the identity key" do
      stub_jwks
      claims = described_class.verify(apple_token, nonce: raw_nonce)

      expect(claims.provider).to eq("apple")
      expect(claims.provider_uid).to eq("apple-sub-001")
      expect(claims.email).to eq("jane@example.com")
    end

    it "accepts a normal (non-relay) Apple email" do
      stub_jwks
      claims = described_class.verify(apple_token, nonce: raw_nonce)

      expect(claims.email).to eq("jane@example.com")
      expect(claims.private_relay_email?).to be false
    end
    it "accepts and flags an Apple private relay email" do
      stub_jwks
      claims = described_class.verify(
        apple_token({ "email" => "abc123xyz@privaterelay.appleid.com",
                      "is_private_email" => "true" }),
        nonce: raw_nonce
      )

      expect(claims.email).to eq("abc123xyz@privaterelay.appleid.com")
      expect(claims.private_relay_email?).to be true
      # The relay address is still Apple-asserted, but SocialLogin refuses to
      # auto-link on it (see Authentication::SocialLogin).
      expect(claims.email_verified?).to be true
    end

    it "still resolves the identity when Apple omits the email after first authorisation" do
      stub_jwks
      # Apple only includes `email` in the very first identity token.
      claims = described_class.verify(
        apple_token({ "email" => nil, "email_verified" => nil }),
        nonce: raw_nonce
      )

      expect(claims.provider_uid).to eq("apple-sub-001")
      expect(claims.email).to be_nil
    end

    it "requires the nonce to match the digest Apple echoed back" do
      stub_jwks
      expect { described_class.verify(apple_token, nonce: "a-different-nonce") }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_nonce) }
    end

    it "rejects a request that supplies no nonce at all" do
      stub_jwks
      expect { described_class.verify(apple_token) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_nonce) }
    end

    it "rejects a token whose nonce claim is missing" do
      stub_jwks
      expect { described_class.verify(apple_token({ "nonce" => nil }), nonce: raw_nonce) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_nonce) }
    end

    it "rejects a token signed by an unknown key" do
      stub_jwks
      expect { described_class.verify(apple_token(signing_key: other_key), nonce: raw_nonce) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects an expired token" do
      stub_jwks
      expect { described_class.verify(apple_token({ "exp" => 10.minutes.ago.to_i }), nonce: raw_nonce) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a token for another audience" do
      stub_jwks
      expect { described_class.verify(apple_token({ "aud" => "com.someone.else" }), nonce: raw_nonce) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a token from an unexpected issuer" do
      stub_jwks
      expect { described_class.verify(apple_token({ "iss" => "https://evil.example.com" }), nonce: raw_nonce) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a token without a subject" do
      stub_jwks
      expect { described_class.verify(apple_token({ "sub" => nil }), nonce: raw_nonce) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "rejects a blank credential" do
      stub_jwks
      expect { described_class.verify("", nonce: raw_nonce) }
        .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
    end

    it "raises a safe error when the app is not configured" do
      with_env("APPLE_CLIENT_ID" => nil) do
        expect { described_class.verify(apple_token, nonce: raw_nonce) }
          .to raise_error(Authentication::Error) { |e|
            expect(e.code).to eq(:provider_not_configured)
            expect(e.status).to eq(:service_unavailable)
          }
      end
    end
  end
end
