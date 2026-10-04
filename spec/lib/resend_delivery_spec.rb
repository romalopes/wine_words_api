# frozen_string_literal: true

require "rails_helper"

RSpec.describe ResendDelivery do
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
    it "maps the sender as a string, recipients as strings and both body parts" do
      payload = delivery.payload_for(mail)

      expect(payload[:from]).to eq("Wine Words <romalopes@gmail.com>")
      expect(payload[:to]).to eq([ "alice@example.com", "bob@example.com" ])
      expect(payload[:subject]).to eq("Reset password instructions")
      expect(payload[:reply_to]).to eq("support@example.com")
      expect(payload[:html]).to eq("<p>HTML body</p>")
      expect(payload[:text]).to eq("Plain body")
    end

    it "maps cc and bcc when present" do
      mail.cc = [ "cc@example.com" ]
      mail.bcc = [ "bcc@example.com" ]

      payload = delivery.payload_for(mail)

      expect(payload[:cc]).to eq([ "cc@example.com" ])
      expect(payload[:bcc]).to eq([ "bcc@example.com" ])
    end

    it "omits the display name when the sender has none" do
      mail.from = "romalopes@gmail.com"

      expect(delivery.payload_for(mail)[:from]).to eq("romalopes@gmail.com")
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
      expect(payload).not_to have_key(:reply_to)
      expect(payload).not_to have_key(:attachments)
      expect(payload).not_to have_key(:html)
      expect(payload[:text]).to eq("hi")
    end

    it "base64-encodes attachments using Resend's filename field" do
      mail.attachments["notes.txt"] = "hello attachment"

      payload = delivery.payload_for(mail)

      expect(payload[:attachments]).to eq(
        [ { filename: "notes.txt", content: Base64.strict_encode64("hello attachment") } ]
      )
    end
  end

  describe "#deliver!" do
    it "POSTs the payload to the Resend endpoint with Bearer auth" do
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

      expect(captured_request.path).to eq("/emails")
      expect(captured_request["Authorization"]).to eq("Bearer test-api-key")
      expect(captured_request["Content-Type"]).to eq("application/json")
      body = JSON.parse(captured_request.body)
      expect(body["subject"]).to eq("Reset password instructions")
      expect(body["from"]).to eq("Wine Words <romalopes@gmail.com>")
      expect(body["to"]).to eq([ "alice@example.com", "bob@example.com" ])
    end

    it "raises when the API responds with a non-2xx status" do
      bad = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      allow(bad).to receive(:body).and_return('{"message":"Invalid `from` field","name":"validation_error"}')
      allow(Net::HTTP).to receive(:start) do |*_args, **_kwargs, &block|
        block.call(instance_double(Net::HTTP, request: bad))
      end

      expect { delivery.deliver!(mail) }
        .to raise_error(ResendDelivery::Error, /Resend API responded 400/)
    end

    it "adds an actionable hint when the API key is rejected" do
      unauthorized = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
      allow(unauthorized).to receive(:body).and_return('{"message":"API key is invalid","name":"validation_error"}')
      allow(Net::HTTP).to receive(:start) do |*_args, **_kwargs, &block|
        block.call(instance_double(Net::HTTP, request: unauthorized))
      end

      expect { delivery.deliver!(mail) }
        .to raise_error(ResendDelivery::Error, /RESEND_API_KEY/)
    end

    it "adds an actionable hint when the sending domain is not verified" do
      forbidden = Net::HTTPForbidden.new("1.1", "403", "Forbidden")
      allow(forbidden).to receive(:body).and_return(
        '{"message":"The domain example.com is not verified","name":"validation_error"}'
      )
      allow(Net::HTTP).to receive(:start) do |*_args, **_kwargs, &block|
        block.call(instance_double(Net::HTTP, request: forbidden))
      end

      expect { delivery.deliver!(mail) }
        .to raise_error(ResendDelivery::Error, %r{resend\.com/domains})
    end

    it "wraps transport failures (e.g. timeouts) in ResendDelivery::Error" do
      allow(delivery).to receive(:post_json).and_raise(Net::OpenTimeout)

      expect { delivery.deliver!(mail) }
        .to raise_error(ResendDelivery::Error, /Net::OpenTimeout/)
    end

    it "raises a clear error when the API key is missing" do
      without_key = described_class.new(api_key: nil)

      expect { without_key.deliver!(mail) }
        .to raise_error(ResendDelivery::Error, /RESEND_API_KEY/)
    end
  end
end
