# frozen_string_literal: true

# Tests for DynamicDelivery, the runtime-switchable delivery adapter registered
# as ActionMailer's process-wide delivery method (config/application.rb).
#
# The critical behaviour under test: the adapter re-resolves the transport on
# EVERY delivery — first from a per-message transport option, then from the
# AppSetting.mail_transport runtime override, then from ENV — so switching
# providers while the application is running (e.g. from the :test fallback to
# Brevo) takes effect on the very next message without a restart.
require "rails_helper"

RSpec.describe DynamicDelivery do
  let(:mail) do
    Mail.new(
      from: "Wine Words <support@wine-words.com>",
      to: "jane@doe.com",
      subject: "Dynamic delivery",
      body: "Hello from the dynamic transport"
    )
  end

  # Fully controlled "environment": DynamicDelivery#runtime_env copies
  # ENV.to_h, so stubbing it makes the specs independent of the machine's
  # actual env vars.
  let(:env) { {} }

  before do
    allow(ENV).to receive(:to_h).and_return(env)
    allow(AppSetting).to receive(:mail_transport).and_return("auto")
    allow(AppSetting).to receive(:brevo_api_key).and_return(nil)
    allow(AppSetting).to receive(:resend_api_key).and_return(nil)
  end

  # --------------------------------------------------------------------------
  # transport_name — the resolution order (per-message > runtime > env > auto)
  # --------------------------------------------------------------------------
  describe "#transport_name" do
    it "prefers an explicit per-message transport over every setting" do
      allow(AppSetting).to receive(:mail_transport).and_return("file")

      expect(described_class.new(transport: "test").transport_name).to eq("test")
    end

    it "falls back to the runtime/env resolution for an unknown per-message transport" do
      # A typo must never silently disable mail — it degrades to the normal
      # resolution (auto => file when nothing is configured).
      expect(described_class.new(transport: "sendgrid").transport_name).to eq("file")
    end

    it "resolves through MailTransport with the AppSetting override" do
      allow(AppSetting).to receive(:mail_transport).and_return("smtp")
      env["SMTP_ADDRESS"] = "smtp.gmail.com"

      expect(described_class.new.transport_name).to eq("smtp")
    end

    it "resolves automatically when nothing is configured" do
      expect(described_class.new.transport_name).to eq("file")
    end
  end

  # --------------------------------------------------------------------------
  # Runtime switching — the reason this adapter exists
  # --------------------------------------------------------------------------
  describe "runtime switching" do
    it "picks up a runtime setting change between deliveries (test -> brevo)" do
      adapter = described_class.new

      # Boot state: nothing configured, automatic selection falls back to file.
      expect(adapter.transport_name).to eq("file")

      # The operator sets an API key and flips the Configuration-page setting.
      env["BREVO_API_KEY"] = "brevo-key"
      allow(AppSetting).to receive(:mail_transport).and_return("brevo")

      expect(adapter.transport_name).to eq("brevo")

      # ...and back to the automatic selection without a restart.
      allow(AppSetting).to receive(:mail_transport).and_return("auto")
      expect(adapter.transport_name).to eq("brevo") # key still present

      env.delete("BREVO_API_KEY")
      expect(adapter.transport_name).to eq("file")
    end

    it "uses API keys saved in app_settings when the env var is missing" do
      env["MAIL_TRANSPORT"] = "brevo"
      allow(AppSetting).to receive(:brevo_api_key).and_return("setting-key")

      expect(described_class.new.transport_name).to eq("brevo")
    end

    it "prefers the env API key over the app_settings value" do
      env["BREVO_API_KEY"] = "env-key"
      allow(AppSetting).to receive(:brevo_api_key).and_return("setting-key")

      expect(described_class.new(transport: "brevo").send(:credential, "brevo"))
        .to eq("env-key")
    end
  end

  # --------------------------------------------------------------------------
  # deliver! — dispatch to the selected provider
  # --------------------------------------------------------------------------
  describe "#deliver!" do
    it "dispatches to BrevoDelivery with the resolved API key" do
      env["BREVO_API_KEY"] = "brevo-key"

      delivery = instance_double(BrevoDelivery, deliver!: true)
      expect(BrevoDelivery).to receive(:new).with(
        api_key: "brevo-key", open_timeout: 10, read_timeout: 10
      ).and_return(delivery)

      expect(described_class.new.deliver!(mail)).to be(true)
    end

    it "dispatches to ResendDelivery with the resolved API key" do
      env["RESEND_API_KEY"] = "resend-key"

      delivery = instance_double(ResendDelivery, deliver!: true)
      expect(ResendDelivery).to receive(:new).with(
        api_key: "resend-key", open_timeout: 10, read_timeout: 10
      ).and_return(delivery)

      expect(described_class.new.deliver!(mail)).to be(true)
    end

    it "raises a clear error when the forced Brevo transport has no API key" do
      expect { described_class.new(transport: "brevo").deliver!(mail) }
        .to raise_error(DynamicDelivery::Error, /BREVO_API_KEY is not configured/)
    end

    it "builds an SMTP delivery mirroring the production env-var contract" do
      env["SMTP_ADDRESS"] = "smtp.test.local"
      env["SMTP_USERNAME"] = "user"
      env["SMTP_PASSWORD"] = "secret"

      smtp = described_class.new(transport: "smtp").send(:build_delivery, "smtp")
      expect(smtp).to be_a(Mail::SMTP)
      expect(smtp.settings[:address]).to eq("smtp.test.local")
      expect(smtp.settings[:user_name]).to eq("user")
    end

    it "writes file deliveries to tmp/mails" do
      file = described_class.new(transport: "file").send(:build_delivery, "file")
      expect(file).to be_a(Mail::FileDelivery)
      expect(file.settings[:location]).to eq(Rails.root.join("tmp/mails"))
    end

    it "delivers through the test transport into Mail::TestMailer.deliveries" do
      expect do
        described_class.new(transport: "test").deliver!(mail)
      end.to change(Mail::TestMailer.deliveries, :count).by(1)

      expect(Mail::TestMailer.deliveries.last.subject).to eq("Dynamic delivery")
    end

    it "wraps unexpected delivery errors with the transport name" do
      env["BREVO_API_KEY"] = "brevo-key"
      delivery = instance_double(BrevoDelivery)
      allow(BrevoDelivery).to receive(:new).and_return(delivery)
      allow(delivery).to receive(:deliver!).and_raise(StandardError, "connection refused")

      expect { described_class.new.deliver!(mail) }
        .to raise_error(DynamicDelivery::Error, /Brevo delivery failed.*connection refused/)
    end

    it "re-raises provider-level errors unwrapped" do
      env["RESEND_API_KEY"] = "resend-key"
      delivery = instance_double(ResendDelivery)
      allow(ResendDelivery).to receive(:new).and_return(delivery)
      allow(delivery).to receive(:deliver!)
        .and_raise(ResendDelivery::Error, "Resend API responded 401: {}")

      expect { described_class.new.deliver!(mail) }
        .to raise_error(ResendDelivery::Error, /401/)
    end
  end
end
