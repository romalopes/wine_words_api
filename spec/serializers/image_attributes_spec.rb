require 'spec_helper'
require 'active_support/all'
require 'active_support/testing/time_helpers'
require 'erb'
require 'uri'
require_relative '../../app/serializers/image_attributes'

RSpec.describe ImageAttributes do
  include ActiveSupport::Testing::TimeHelpers

  let(:serializer_class) do
    Class.new do
      include ImageAttributes
      def initialize
        @base_url = 'https://api.example.com'
      end
    end
  end
  let(:serializer) { serializer_class.new }
  let(:blob) do
    double('blob', service_name: 'cloudflare_r2', key: 'folder/image key',
           filename: 'wine.jpg', content_type: 'image/jpeg')
  end
  let(:current) { Class.new { class << self; attr_accessor :url_options; end } }

  before do
    stub_const('ActiveStorage', Module.new)
    stub_const('ActiveStorage::Current', current)
    ActiveStorage.define_singleton_method(:service_urls_expire_in) { 300 }
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CLOUD_FLARE_R2_PUBLIC_URL').and_return(nil)
    described_class::SIGNED_URL_CACHE.clear
  end

  after { travel_back }

  def url(instance = serializer)
    instance.send(:blob_url, blob)
  end

  it 'uses the public domain without signing and escapes object keys' do
    allow(ENV).to receive(:[]).with('CLOUD_FLARE_R2_PUBLIC_URL').and_return('https://images.example.com/')
    expect(blob).not_to receive(:url)
    expect(url).to eq('https://images.example.com/folder/image%20key')
  end

  it 'reuses signed URLs across serializer instances, refreshing before expiry' do
    travel_to(Time.utc(2026, 10, 16))
    expect(blob).to receive(:url).with(disposition: :inline, expires_in: 300.0).once.and_return('https://storage.example/first')
    expect(url).to eq('https://storage.example/first')
    travel 239.seconds
    expect(url(serializer_class.new)).to eq('https://storage.example/first')
    travel 2.seconds
    expect(blob).to receive(:url).with(disposition: :inline, expires_in: 300.0).once.and_return('https://storage.example/second')
    expect(url).to eq('https://storage.example/second')
  end

  it 'keeps other storage services on their existing URL path' do
    allow(ENV).to receive(:[]).with('CLOUD_FLARE_R2_PUBLIC_URL').and_return('https://images.example.com')
    allow(blob).to receive(:service_name).and_return('test')
    expect(blob).to receive(:url).with(disposition: :inline).twice.and_return('/disk/image')
    2.times { expect(url).to eq('https://api.example.com/disk/image') }
    expect(current.url_options).to be_nil
  end

  it 'falls back to signing for invalid public domain configuration' do
    allow(ENV).to receive(:[]).with('CLOUD_FLARE_R2_PUBLIC_URL').and_return('not a URL')
    expect(blob).to receive(:url).and_return('https://storage.example/signed')
    expect(url).to eq('https://storage.example/signed')
  end

  it 'does not cache redirect fallbacks after signing fails' do
    routes = double('routes', rails_blob_url: 'https://api.example/redirect')
    stub_const('Rails', double('Rails', logger: double(warn: nil),
      application: double(routes: double(url_helpers: routes))))
    expect(blob).to receive(:url).ordered.and_raise(StandardError, 'temporary failure')
    expect(url).to eq('https://api.example/redirect')
    expect(blob).to receive(:url).ordered.and_return('https://storage.example/recovered')
    expect(url).to eq('https://storage.example/recovered')
    expect(current.url_options).to be_nil
  end
end
