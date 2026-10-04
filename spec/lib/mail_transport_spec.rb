# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailTransport do
  def resolve(env, logger: nil)
    described_class.resolve(env, logger: logger)
  end

  it "prefers Brevo when BREVO_API_KEY is present" do
    expect(resolve({ "BREVO_API_KEY" => "key" })).to eq("brevo")
  end

  it "uses SMTP when only SMTP_ADDRESS is set" do
    expect(resolve({ "SMTP_ADDRESS" => "smtp.gmail.com" })).to eq("smtp")
  end

  it "uses Resend when only RESEND_API_KEY is set" do
    expect(resolve({ "RESEND_API_KEY" => "key" })).to eq("resend")
  end

  it "keeps Brevo as the automatic choice when both API keys are set" do
    expect(resolve({ "BREVO_API_KEY" => "a", "RESEND_API_KEY" => "b" })).to eq("brevo")
  end

  it "falls back to file when nothing is configured" do
    expect(resolve({})).to eq("file")
  end

  it "lets MAIL_TRANSPORT override the automatic selection" do
    configured = {
      "BREVO_API_KEY" => "brevo-key",
      "RESEND_API_KEY" => "resend-key",
      "SMTP_ADDRESS" => "smtp.gmail.com"
    }

    expect(resolve(configured.merge("MAIL_TRANSPORT" => "smtp"))).to eq("smtp")
    expect(resolve(configured.merge("MAIL_TRANSPORT" => "file"))).to eq("file")
    expect(resolve(configured.merge("MAIL_TRANSPORT" => "brevo"))).to eq("brevo")
    expect(resolve(configured.merge("MAIL_TRANSPORT" => "resend"))).to eq("resend")
  end

  it "treats MAIL_TRANSPORT=auto (or blank) as the automatic selection" do
    env = { "SMTP_ADDRESS" => "smtp.gmail.com", "MAIL_TRANSPORT" => "auto" }

    expect(resolve(env)).to eq("smtp")
    expect(resolve(env.merge("MAIL_TRANSPORT" => "  "))).to eq("smtp")
  end

  it "ignores an unknown MAIL_TRANSPORT value" do
    expect(resolve({ "BREVO_API_KEY" => "key", "MAIL_TRANSPORT" => "sendgrid" })).to eq("brevo")
  end

  it "falls back when the requested transport is missing its credentials" do
    expect(resolve({ "SMTP_ADDRESS" => "smtp.gmail.com", "MAIL_TRANSPORT" => "brevo" })).to eq("smtp")
    expect(resolve({ "BREVO_API_KEY" => "key", "MAIL_TRANSPORT" => "smtp" })).to eq("brevo")
    expect(resolve({ "MAIL_TRANSPORT" => "brevo" })).to eq("file")
    expect(resolve({ "BREVO_API_KEY" => "key", "MAIL_TRANSPORT" => "resend" })).to eq("brevo")
    expect(resolve({ "MAIL_TRANSPORT" => "resend" })).to eq("file")
  end

  it "warns when multiple API keys are set without an explicit MAIL_TRANSPORT" do
    logger = instance_double(Logger)

    expect(logger).to receive(:warn)
      .with(/BREVO_API_KEY and RESEND_API_KEY are both set; using brevo/)

    expect(resolve({ "BREVO_API_KEY" => "a", "RESEND_API_KEY" => "b" }, logger: logger)).to eq("brevo")
  end

  it "warns when it ignores a MAIL_TRANSPORT value" do
    logger = instance_double(Logger)

    expect(logger).to receive(:warn)
      .with(/MAIL_TRANSPORT=brevo requires BREVO_API_KEY; using file instead/)

    expect(resolve({ "MAIL_TRANSPORT" => "brevo" }, logger: logger)).to eq("file")
  end
end
