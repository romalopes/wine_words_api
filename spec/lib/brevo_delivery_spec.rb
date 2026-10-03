# frozen_string_literal: true

require "rails_helper"

RSpec.describe BrevoDelivery do
  subject(:delivery) do
    described_class.new(api_key: "test-api-key", open_timeout: 5, read_timeout: 5)
  end

  let(:mail) do
    Mail.new.tap do |message|
      message.from = "Wine Words <romalopes@gmail.com>"
      message.to = [ "alice@example.com", "bob@example.com" ]
      message.reply_to = "support@example.com"
      message.subject = "Reset password instructions"
      message.text_part = Mail::Part.new { body "Plain body" }
      message.html_part = Mail::Part.new { body "<p>HTML body</p>" }
    end
  end

  describe "#payload_for" do
    it "maps sender, recipients, subject, reply-to and both body parts" do
      payload = delivery.payload_for(mail)

      expect(payload[:sender]).to eq(email: "romalopes@gmail.com", name: "Wine Words")
      expect(payload[:to]).to eq(
        [ { email: "alice@example.com" }, { email: "bob@example.com" } ]
      )
      expect(payload[:subject]).to eq("Reset password instructions")
      expect(payload[:replyTo]).to eq(email: "support@example.com")
      expect(payload[:htmlContent]).to eq("<p>HTML body</p>")
      expect(payload[:textContent]).to eq("Plain body")
    end

    it "maps cc and bcc when present" do
      mail.cc = [ "cc@example.com" ]
      mail.bcc = [ "bcc@example.com" ]

      payload = delivery.payload_for(mail)

      expect(payload[:cc]).to eq([ { email: "cc@example.com" } ])
      expect(payload[:bcc]).to eq([ { email: "bcc@example.com" } ])
    end

    it "omits optional fields that are not present" do
      plain = Mail.new do
        from "a@example.com"
        to "c@example.com"
        subject "Hi"
        body "hi"
      end

      payload = delivery.payload_for(plain)

      expect(payload).not_to have_key(:cc)
      expect(payload).not_to have_key(:bcc)
      expect(payload).not_to have_key(:replyTo)
      expect(payload).not_to have_key(:attachment)
      expect(payload).not_to have_key(:htmlContent)
      expect(payload[:textContent]).to eq("hi")
    end

    it "base64-encodes attachments" do
      mail.attachments["notes.txt"] = "hello attachment"

      payload = delivery.payload_for(mail)

      expect(payload[:attachment]).to eq(
        [ { name: "notes.txt", content: Base64.strict_encode64("hello attachment") } ]
      )
    end
  end

  describe "#deliver!" do
    it "POSTs the payload to the Brevo endpoint with the api-key header" do
      ok = Net::HTTPOK.new("1.1", "200", "OK")
      captured_request = nil

      fake_http = instance_double(Net::HTTP)
      allow(fake_http).to receive(:request) do |request|
        captured_request = request
        ok
      end
      allow(Net::HTTP).to receive(:start) do |*_args, **_kwargs, &block|
        block.call(fake_http)
      end

      expect(delivery.deliver!(mail)).to be(true)

      expect(captured_request.path).to eq("/v3/smtp/email")
      expect(captured_request["api-key"]).to eq("test-api-key")
      expect(captured_request["Content-Type"]).to eq("application/json")
      body = JSON.parse(captured_request.body)
      expect(body["subject"]).to eq("Reset password instructions")
      expect(body["sender"]).to eq("email" => "romalopes@gmail.com", "name" => "Wine Words")
    end

    it "raises when the API responds with a non-2xx status" do
      bad = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      # Synthetic responses have no socket to read from; stub the body.
      allow(bad).to receive(:body).and_return('{"code":"invalid_parameter"}')
      allow(Net::HTTP).to receive(:start) do |*_args, **_kwargs, &block|
        block.call(instance_double(Net::HTTP, request: bad))
      end

      expect { delivery.deliver!(mail) }
        .to raise_error(BrevoDelivery::Error, /Brevo API responded 400/)
    end

    it "wraps transport failures (e.g. timeouts) in BrevoDelivery::Error" do
      allow(delivery).to receive(:http_post).and_raise(Net::OpenTimeout)

      expect { delivery.deliver!(mail) }
        .to raise_error(BrevoDelivery::Error, /Net::OpenTimeout/)
    end

    it "raises a clear error when the API key is missing" do
      without_key = described_class.new(api_key: nil)

      expect { without_key.deliver!(mail) }
        .to raise_error(BrevoDelivery::Error, /BREVO_API_KEY/)
    end
  end
end
