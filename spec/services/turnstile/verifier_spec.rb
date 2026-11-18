require "rails_helper"

# Cloudflare Turnstile server-side verification (IDENTITY_209 Phase 5).
# The transport is injected, so no network request is made.
RSpec.describe Turnstile::Verifier do
  def client_returning(payload)
    instance_double(Turnstile::Verifier::NativeClient, post: payload)
  end

  let(:enabled_env) do
    { "TURNSTILE_ENABLED" => "true", "TURNSTILE_SECRET_KEY" => "secret-key" }
  end

  def verify(env: enabled_env, token: "visitor-token", client: client_returning({ "success" => true }))
    described_class.call(token: token, remote_ip: "203.0.113.5", env: env, client: client)
  end

  it "is disabled outside production unless explicitly enabled" do
    expect(described_class.enabled?({})).to be(false)
    expect(described_class.enabled?("TURNSTILE_ENABLED" => "true")).to be(true)
    expect(described_class.enabled?("TURNSTILE_ENABLED" => "false")).to be(false)
  end

  it "passes verification without contacting Cloudflare when disabled" do
    result = verify(env: {}, token: nil, client: client_returning(nil))

    expect(result.success?).to be(true)
  end

  it "fails closed when the secret is missing" do
    result = verify(env: { "TURNSTILE_ENABLED" => "true" })

    expect(result.success?).to be(false)
    expect(result.error_codes).to include("missing-secret")
  end

  it "fails closed when the visitor sends no token" do
    result = verify(token: nil)

    expect(result.success?).to be(false)
    expect(result.error_codes).to include("missing-token")
  end

  it "sends the secret, token and remote IP to Siteverify" do
    client = client_returning({ "success" => true })

    expect(client).to receive(:post) do |uri, params|
      expect(uri.to_s).to eq(Turnstile::Verifier::DEFAULT_VERIFY_URL)
      expect(params).to eq(
        secret: "secret-key", response: "visitor-token", remoteip: "203.0.113.5"
      )
      { "success" => true }
    end

    expect(verify(client: client).success?).to be(true)
  end

  it "returns Cloudflare's error codes for an invalid token" do
    result = verify(client: client_returning(
      { "success" => false, "error-codes" => [ "invalid-input-response" ] }
    ))

    expect(result.success?).to be(false)
    expect(result.error_codes).to eq([ "invalid-input-response" ])
  end

  it "rejects a hostname outside the allowlist" do
    env = enabled_env.merge("TURNSTILE_EXPECTED_HOSTNAMES" => "wine-words.com, www.wine-words.com")

    result = verify(
      env: env,
      client: client_returning({ "success" => true, "hostname" => "evil.example" })
    )

    expect(result.success?).to be(false)
    expect(result.error_codes).to include("hostname-mismatch")

    allowed = verify(
      env: env,
      client: client_returning({ "success" => true, "hostname" => "www.wine-words.com" })
    )
    expect(allowed.success?).to be(true)
  end

  it "rejects an unexpected widget action" do
    env = enabled_env.merge("TURNSTILE_EXPECTED_ACTION" => "contact")

    result = verify(
      env: env,
      client: client_returning({ "success" => true, "action" => "trade" })
    )

    expect(result.success?).to be(false)
    expect(result.error_codes).to include("action-mismatch")
  end

  it "fails closed when Cloudflare is unreachable" do
    client = instance_double(Turnstile::Verifier::NativeClient)
    allow(client).to receive(:post).and_raise(Net::OpenTimeout)

    result = verify(client: client)

    expect(result.success?).to be(false)
    expect(result.error_codes).to include("verification-unavailable")
  end

  it "fails closed on a malformed Siteverify response" do
    result = verify(client: client_returning(nil))

    expect(result.success?).to be(false)
    expect(result.error_codes).to include("verification-unavailable")
  end
end
