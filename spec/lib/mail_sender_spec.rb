# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailSender do
  describe ".from" do
    it "returns MAIL_FROM when set" do
      expect(described_class.from({ "MAIL_FROM" => "Wine Words <no-reply@example.com>" }))
        .to eq("Wine Words <no-reply@example.com>")
    end

    it "ignores a blank MAIL_FROM and falls back to the default" do
      expect(described_class.from({ "MAIL_FROM" => "  " })).to eq(described_class::DEFAULT_FROM)
    end

    it "defaults to the current application sender" do
      expect(described_class.from({})).to eq("kasia@mywineadviser.com.au")
    end
  end

  describe ".reply_to" do
    it "returns MAIL_REPLY_TO when set" do
      expect(described_class.reply_to({ "MAIL_REPLY_TO" => "replies@example.com" }))
        .to eq("replies@example.com")
    end

    it "ignores a blank MAIL_REPLY_TO and falls back to the default" do
      expect(described_class.reply_to({ "MAIL_REPLY_TO" => "" })).to eq(described_class::DEFAULT_REPLY_TO)
    end

    it "defaults to the current reply inbox" do
      expect(described_class.reply_to({})).to eq("romalopes@yahoo.com.br")
    end
  end
end
