# frozen_string_literal: true

require "rails_helper"

RSpec.describe AppVersion do
  describe ".VERSION" do
    it "returns the application version as a string" do
      expect(AppVersion::VERSION).to eq("0.0.20")
    end

    it "is a non-empty string" do
      expect(AppVersion::VERSION).to be_a(String)
      expect(AppVersion::VERSION).not_to be_empty
    end
  end
end
