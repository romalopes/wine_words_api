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

  # --------------------------------------------------------------------------
  # Runtime override (AppSetting.mail_transport)
  #
  # The `override:` keyword is what makes runtime switching possible: it is
  # fed from AppSetting.mail_transport on every DynamicDelivery delivery, so
  # an admin can flip the Configuration-page setting and the next e-mail
  # already goes out through the new provider — no restart.
  # --------------------------------------------------------------------------
  describe "runtime override" do
    def resolve(env, logger: nil, override: nil)
      described_class.resolve(env, logger: logger, override: override)
    end

    let(:configured) do
      {
        "BREVO_API_KEY" => "brevo-key",
        "RESEND_API_KEY" => "resend-key",
        "SMTP_ADDRESS" => "smtp.gmail.com"
      }
    end

    it "wins over the boot-time MAIL_TRANSPORT env var" do
      env = configured.merge("MAIL_TRANSPORT" => "smtp")

      expect(resolve(env, override: "file")).to eq("file")
      expect(resolve(env, override: "brevo")).to eq("brevo")
      expect(resolve(env, override: "resend")).to eq("resend")
    end

    it "treats the override's default (auto) as 'no runtime choice'" do
      env = configured.merge("MAIL_TRANSPORT" => "file")

      # "auto" and blank mean the runtime setting makes no choice, so the
      # boot-time MAIL_TRANSPORT=file from the environment stays in charge.
      expect(resolve(env, override: "auto")).to eq("file")
      expect(resolve(env, override: nil)).to eq("file")
      expect(resolve(env, override: "  ")).to eq("file")
    end

    it "switches from a boot-time file fallback to brevo at runtime" do
      env = { "MAIL_TRANSPORT" => "file" } # nothing else configured at boot

      expect(resolve(env)).to eq("file")
      # The operator saves brevo_api_key into app_settings (or sets the env
      # var) and flips the setting; the very next delivery uses Brevo.
      expect(resolve(env.merge("BREVO_API_KEY" => "brevo-key"), override: "brevo"))
        .to eq("brevo")
    end

    it "falls back to the automatic selection when the override lacks its credentials" do
      env = { "MAIL_TRANSPORT" => "file" }

      expect(resolve(env, override: "brevo")).to eq("file")
      expect(resolve(env, override: "resend")).to eq("file")
      expect(resolve(env, override: "smtp")).to eq("file")
    end

    it "ignores an unknown override value" do
      expect(resolve(configured, override: "sendgrid")).to eq("brevo")
    end

    it "warns when it ignores an override value" do
      logger = instance_double(Logger)

      expect(logger).to receive(:warn)
        .with(/MAIL_TRANSPORT=brevo requires BREVO_API_KEY; using file instead/)

      expect(resolve({ "MAIL_TRANSPORT" => "file" }, logger: logger, override: "brevo"))
        .to eq("file")
    end
  end
end
