require "rails_helper"
require "jwt"
require "openssl"

# Microsoft identity platform (Entra ID) verification, including the documented
# tenant policy: "common" accepts personal + organisational accounts,
# "organizations" rejects the personal (MSA) tenant and "consumers" accepts
# only it. The `iss`/`tid` agreement check is what stops a token from an
# unverified tenant being trusted.
RSpec.describe Authentication::Microsoft, type: :model do
  let(:key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:other_key) { OpenSSL::PKey::RSA.generate(2048) }
  let(:kid) { "ms-test-key" }
  let(:client_id) { "ms-client-id" }
  # A work/school (organisational) tenant and Microsoft's well-known personal
  # ("consumers"/MSA) tenant.
  let(:org_tid) { "11111111-2222-3333-4444-555555555555" }
  let(:msa_tid) { described_class::MSA_TENANT_ID }

  def jwks_document(signing_key = key, key_id: kid)
    jwk = JWT::JWK.new(signing_key, { kid: key_id, use: "sig", alg: "RS256" })
    { "keys" => [ jwk.export ] }
  end

  def stub_jwks(signing_key = key, key_id: kid)
    allow(Authentication::HttpClient).to receive(:get_json)
      .and_return(jwks_document(signing_key, key_id: key_id))
  end

  def ms_token(overrides = {}, tid: org_tid, signing_key: key, key_id: kid)
    JWT.encode(
      {
        "iss" => "https://login.microsoftonline.com/#{tid}/v2.0",
        "aud" => client_id,
        "sub" => "ms-sub-001",
        "tid" => tid,
        "email" => "Person@Example.com",
        "preferred_username" => "Person@Example.com",
        "name" => "Microsoft Person",
        "exp" => 1.hour.from_now.to_i,
        "iat" => Time.current.to_i
      }.merge(overrides),
      signing_key, "RS256", { kid: key_id }
    )
  end

  # Runs the block with the Microsoft client id + tenant policy under test.
  def with_microsoft(tenant: "common", client: client_id, &block)
    with_env("MICROSOFT_CLIENT_ID" => client, "MICROSOFT_TENANT_ID" => tenant, &block)
  end

  describe ".configured?" do
    it "is configured when the client id is present" do
      with_microsoft { expect(described_class.configured?).to be true }
    end

    it "is not configured without a client id" do
      with_microsoft(client: nil) { expect(described_class.configured?).to be false }
    end
  end

  describe ".verify with the default 'common' tenant policy" do
    it "accepts a valid organisational account" do
      with_microsoft do
        stub_jwks
        claims = described_class.verify(ms_token)

        expect(claims.provider).to eq("microsoft")
        # `sub` is the identity key — never the email.
        expect(claims.provider_uid).to eq("ms-sub-001")
        expect(claims.email).to eq("person@example.com")
        expect(claims.metadata[:tenant]).to eq(org_tid)
      end
    end

    it "accepts a personal Microsoft account" do
      with_microsoft do
        stub_jwks
        claims = described_class.verify(ms_token(tid: msa_tid))

        expect(claims.provider_uid).to eq("ms-sub-001")
        expect(claims.metadata[:tenant]).to eq(msa_tid)
      end
    end

    it "treats the address as verified when it matches preferred_username" do
      with_microsoft do
        stub_jwks
        claims = described_class.verify(ms_token)
        expect(claims.email_verified?).to be true
      end
    end

    it "trusts an explicit email_verified claim from a personal account" do
      with_microsoft do
        stub_jwks
        # A personal account whose address differs from its UPN but is
        # explicitly asserted verified by the token itself.
        claims = described_class.verify(
          ms_token({ "email" => "other@example.com",
                     "preferred_username" => "person@outlook.com",
                     "email_verified" => true },
                   tid: msa_tid)
        )

        expect(claims.email_verified?).to be true
      end
    end

    it "does not trust an email claim that disagrees with the directory UPN" do
      with_microsoft do
        stub_jwks
        claims = described_class.verify(
          ms_token({ "email" => "attacker@evil.example.com",
                     "preferred_username" => "person@example.com" })
        )

        expect(claims.email).to eq("attacker@evil.example.com")
        # Disagreement means the address is not directory-authoritative, so it
        # must never be used to auto-link an existing account.
        expect(claims.email_verified?).to be false
      end
    end

    it "falls back to preferred_username when no email claim is present" do
      with_microsoft do
        stub_jwks
        claims = described_class.verify(ms_token({ "email" => nil }))
        expect(claims.email).to eq("person@example.com")
        expect(claims.email_verified?).to be true
      end
    end

    it "rejects a token whose tid disagrees with its verified issuer" do
      with_microsoft do
        stub_jwks
        # iss is for org_tid, but the body claims the personal tenant.
        expect { described_class.verify(ms_token({ "tid" => msa_tid }, tid: org_tid)) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_tenant) }
      end
    end

    it "rejects a token with no tid claim" do
      with_microsoft do
        stub_jwks
        expect { described_class.verify(ms_token({ "tid" => nil })) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_tenant) }
      end
    end

    it "rejects a token signed by an unknown key" do
      with_microsoft do
        stub_jwks
        expect { described_class.verify(ms_token(signing_key: other_key)) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
      end
    end

    it "rejects an expired token" do
      with_microsoft do
        stub_jwks
        expect { described_class.verify(ms_token({ "exp" => 10.minutes.ago.to_i })) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
      end
    end

    it "rejects a token for another audience" do
      with_microsoft do
        stub_jwks
        expect { described_class.verify(ms_token({ "aud" => "another-app" })) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
      end
    end

    it "rejects a token from an unexpected issuer host" do
      with_microsoft do
        stub_jwks
        expect { described_class.verify(ms_token({ "iss" => "https://evil.example.com/#{org_tid}/v2.0" })) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
      end
    end

    it "rejects a blank credential" do
      with_microsoft do
        stub_jwks
        expect { described_class.verify("") }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
      end
    end

    it "raises a safe error when the app is not configured" do
      with_microsoft(client: nil) do
        expect { described_class.verify(ms_token) }
          .to raise_error(Authentication::Error) { |e|
            expect(e.code).to eq(:provider_not_configured)
            expect(e.status).to eq(:service_unavailable)
          }
      end
    end
  end

  describe ".verify with MICROSOFT_TENANT_ID='organizations'" do
    it "accepts an organisational account" do
      with_microsoft(tenant: "organizations") do
        stub_jwks
        expect(described_class.verify(ms_token).provider_uid).to eq("ms-sub-001")
      end
    end

    it "rejects a personal Microsoft account" do
      with_microsoft(tenant: "organizations") do
        stub_jwks
        expect { described_class.verify(ms_token(tid: msa_tid)) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_tenant) }
      end
    end
  end

  describe ".verify with MICROSOFT_TENANT_ID='consumers'" do
    it "accepts a personal Microsoft account" do
      with_microsoft(tenant: "consumers") do
        stub_jwks
        expect(described_class.verify(ms_token(tid: msa_tid)).provider_uid).to eq("ms-sub-001")
      end
    end

    it "rejects an organisational account" do
      with_microsoft(tenant: "consumers") do
        stub_jwks
        expect { described_class.verify(ms_token) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_tenant) }
      end
    end
  end

  describe ".verify with a concrete tenant configured" do
    it "accepts a token issued by exactly that tenant" do
      with_microsoft(tenant: org_tid) do
        stub_jwks
        expect(described_class.verify(ms_token).metadata[:tenant]).to eq(org_tid)
      end
    end

    it "rejects a token issued by a different tenant" do
      with_microsoft(tenant: org_tid) do
        stub_jwks
        expect { described_class.verify(ms_token(tid: msa_tid)) }
          .to raise_error(Authentication::Error) { |e| expect(e.code).to eq(:invalid_credential) }
      end
    end
  end
end