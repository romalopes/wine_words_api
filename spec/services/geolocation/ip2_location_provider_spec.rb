# frozen_string_literal: true

require "rails_helper"

RSpec.describe Geolocation::Ip2LocationProvider do
  subject(:provider) { described_class.new }

  it "does not call the external service for a loopback or private address" do
    expect(Net::HTTP).not_to receive(:new)

    expect(provider.resolve("::1")).to be_nil
    expect(provider.resolve("192.168.1.10")).to be_nil
  end

  it "is selected by the Zeitwerk-compatible provider factory" do
    expect(Geolocation::Provider.provider_for("ip2location")).to be_a(described_class)
    expect(Geolocation::Provider.provider_for("none")).to be_a(Geolocation::NullProvider)
  end
end