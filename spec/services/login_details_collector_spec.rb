# frozen_string_literal: true

require "rails_helper"

RSpec.describe LoginDetailsCollector do
  let(:desktop_user_agent) do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36"
  end
  let(:mobile_user_agent) do
    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
  end

  def request_with(user_agent:, remote_ip: "203.0.113.10")
    ActionDispatch::TestRequest.create(
      "HTTP_USER_AGENT" => user_agent,
      "REMOTE_ADDR" => remote_ip
    )
  end

  before do
    allow(Geolocation::Provider).to receive(:resolve).and_return(nil)
  end

  it "extracts desktop browser, version, operating system, and device details" do
    details = described_class.collect(request_with(user_agent: desktop_user_agent), login_method: "password")

    expect(details.ip_address).to eq("203.0.113.10")
    expect(details.browser).to eq("Chrome")
    expect(details.browser_version).to start_with("155")
    expect(details.os).not_to eq(LoginDetails::UNKNOWN)
    expect(details.device).to eq("Desktop")
    expect(details.mobile?).to be(false)
  end

  it "classifies a mobile browser as mobile" do
    details = described_class.collect(request_with(user_agent: mobile_user_agent), login_method: "password")

    expect(details.browser).to eq("Safari")
    expect(details.os).not_to eq(LoginDetails::UNKNOWN)
    expect(details.device).not_to eq(LoginDetails::UNKNOWN)
    expect(details.mobile?).to be(true)
  end

  it "degrades only user-agent-derived fields when the header is absent" do
    details = described_class.collect(request_with(user_agent: nil), login_method: "password")

    expect(details.ip_address).to eq("203.0.113.10")
    expect(details.user_agent).to eq(LoginDetails::UNKNOWN)
    expect(details.browser).to eq(LoginDetails::UNKNOWN)
    expect(details.browser_version).to eq(LoginDetails::UNKNOWN)
    expect(details.os).to eq(LoginDetails::UNKNOWN)
    expect(details.device).to eq(LoginDetails::UNKNOWN)
  end

  it "keeps the local IP and reports an unknown location for loopback sign-ins" do
    details = described_class.collect(request_with(user_agent: desktop_user_agent, remote_ip: "::1"))

    expect(details.ip_address).to eq("::1")
    expect(details.location).to eq(LoginDetails::UNKNOWN)
  end
end