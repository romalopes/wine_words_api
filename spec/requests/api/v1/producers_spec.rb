require "rails_helper"
require "devise"

# Request specs for Api::V1::ProducersController — the JSON endpoints the
# React app relies on. Covers creation (country/regions/grapes/logo),
# updates (fields + relationship replacement + logo replacement), deletion
# (join records + attachments) and validations.
RSpec.describe "Api::V1::Producers", type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:australia) do
    Country.find_by(code: "AU") ||
      Country.create!(name: "Australia", code: "AU", continent: "Oceania", flag_emoji: "🇦🇺")
  end
  let(:new_zealand) do
    Country.create!(name: "New Zealand", code: "NZ", continent: "Oceania", flag_emoji: "🇳🇿")
  end
  let!(:region_sa) { Region.create!(name: "South Australia", country: australia) }
  let!(:region_marlborough) { Region.create!(name: "Marlborough", country: new_zealand) }
  let!(:grape_shiraz) { Grape.create!(name: "Shiraz", color: "red") }
  let!(:grape_riesling) { Grape.create!(name: "Riesling", color: "white") }

  let(:super_user) do
    User.create!(name: "Super", email: "super@example.com", password: "password123")
  end

  before do
    super_user.roles << Role.find_or_create_by!(name: "Super User")
  end

  def producer_attributes
    {
      name: "Penfolds",
      email: "cellar@penfolds.com",
      legal_name: "Penfolds Wines Pty Ltd",
      phone: "+61 8 8208 0200",
      city: "Adelaide",
      state: "SA",
      postal_code: "5092",
      founded_year: 1844,
      active: true,
      website: "https://penfolds.com",
      region_ids: [region_sa.id],
      grape_ids: [grape_shiraz.id, grape_riesling.id]
    }
  end

  def logo_file
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/logo.png"), "image/png"
    )
  end

  describe "POST /api/v1/producers" do
    context "as a Super User" do
      before { sign_in super_user }

      it "creates the producer and returns 201" do
        expect {
          post "/api/v1/producers", params: { producer: producer_attributes }, as: :json
        }.to change(Producer, :count).by(1)
        expect(response).to have_http_status(:created)
      end

      it "assigns the country (defaults to Australia when absent)" do
        post "/api/v1/producers", params: { producer: producer_attributes.except(:country_id) }, as: :json
        expect(Producer.last.country).to eq(australia)
      end

      it "assigns regions and grapes" do
        post "/api/v1/producers", params: { producer: producer_attributes }, as: :json
        producer = Producer.last
        expect(producer.regions).to contain_exactly(region_sa)
        expect(producer.grapes).to contain_exactly(grape_shiraz, grape_riesling)
      end

      it "dedupes repeated region and grape ids" do
        attrs = producer_attributes.merge(
          region_ids: [region_sa.id, region_sa.id],
          grape_ids: [grape_shiraz.id, grape_shiraz.id]
        )
        post "/api/v1/producers", params: { producer: attrs }, as: :json
        expect(response).to have_http_status(:created)
        expect(Producer.last.producer_regions.count).to eq(1)
        expect(Producer.last.producer_grapes.count).to eq(1)
      end

      it "rejects a region outside the producer's country" do
        attrs = producer_attributes.merge(region_ids: [region_marlborough.id])
        post "/api/v1/producers", params: { producer: attrs }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["errors"].join).to match(/country/i)
      end

      it "rejects an invalid founded year" do
        attrs = producer_attributes.merge(founded_year: Date.current.year + 5)
        post "/api/v1/producers", params: { producer: attrs }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "accepts a valid founded year equal to the current year" do
        attrs = producer_attributes.merge(founded_year: Date.current.year)
        post "/api/v1/producers", params: { producer: attrs }, as: :json
        expect(response).to have_http_status(:created)
      end

      it "returns the serialized new attributes" do
        post "/api/v1/producers", params: { producer: producer_attributes }, as: :json
        body = JSON.parse(response.body)
        expect(body).to include(
          "legal_name" => "Penfolds Wines Pty Ltd",
          "phone" => "+61 8 8208 0200",
          "city" => "Adelaide",
          "founded_year" => 1844,
          "active" => true
        )
        expect(body["country"]["code"]).to eq("AU")
        expect(body["grapes"].map { |g| g["name"] }).to match_array(["Shiraz", "Riesling"])
      end
    end

    context "as a Guest" do
      let(:guest) do
        User.create!(name: "Guest", email: "guest@example.com", password: "password123")
      end

      before { sign_in guest }

      it "returns 403 Forbidden" do
        post "/api/v1/producers", params: { producer: producer_attributes }, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authentication" do
      it "returns 401 Unauthorized" do
        post "/api/v1/producers", params: { producer: producer_attributes }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/producers/:id" do
    let!(:producer) do
      Producer.create!(producer_attributes.except(:region_ids, :grape_ids)).tap do |p|
        p.regions << region_sa
        p.grapes << [grape_shiraz, grape_riesling]
      end
    end

    it "returns the producer with country, regions, grapes and logo_url" do
      get "/api/v1/producers/#{producer.slug}"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("Penfolds")
      expect(body["country"]["name"]).to eq("Australia")
      expect(body["regions"].first).to include("name" => "South Australia", "country_name" => "Australia")
      expect(body["grapes"].size).to eq(2)
      expect(body).to have_key("logo_url")
      expect(body).to have_key("images")
      expect(body).to have_key("wines")
    end

    it "returns 404 for a missing producer" do
      get "/api/v1/producers/does-not-exist"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/producers/:id" do
    let!(:producer) do
      Producer.create!(producer_attributes.except(:region_ids, :grape_ids)).tap do |p|
        p.regions << region_sa
        p.grapes << grape_shiraz
      end
    end

    before { sign_in super_user }

    it "updates simple fields" do
      patch "/api/v1/producers/#{producer.slug}",
            params: { producer: { phone: "1234", founded_year: 1900, legal_name: "New Legal Co" } },
            as: :json
      expect(response).to have_http_status(:ok)
      producer.reload
      expect(producer.phone).to eq("1234")
      expect(producer.founded_year).to eq(1900)
      expect(producer.legal_name).to eq("New Legal Co")
    end

    it "replaces relationships" do
      patch "/api/v1/producers/#{producer.slug}",
            params: { producer: { region_ids: [region_sa.id], grape_ids: [grape_riesling.id] } },
            as: :json
      producer.reload
      expect(producer.grapes).to contain_exactly(grape_riesling)
      expect(producer.regions).to contain_exactly(region_sa)
    end

    it "removes all regions when the country changes" do
      patch "/api/v1/producers/#{producer.slug}",
            params: { producer: { country_id: new_zealand.id, region_ids: [] } },
            as: :json
      expect(response).to have_http_status(:ok)
      producer.reload
      expect(producer.country).to eq(new_zealand)
      expect(producer.regions).to be_empty
    end

    it "clears stale regions automatically when only the country changes" do
      patch "/api/v1/producers/#{producer.slug}",
            params: { producer: { country_id: new_zealand.id } },
            as: :json
      producer.reload
      expect(producer.producer_regions).to be_empty
    end
  end

  describe "DELETE /api/v1/producers/:id" do
    let!(:producer) do
      Producer.create!(producer_attributes.except(:region_ids, :grape_ids)).tap do |p|
        p.regions << region_sa
        p.grapes << grape_shiraz
        p.logo.attach(logo_file)
      end
    end

    before { sign_in super_user }

    it "destroys the producer and returns 204" do
      expect {
        delete "/api/v1/producers/#{producer.slug}"
      }.to change(Producer, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "removes the join records" do
      expect {
        delete "/api/v1/producers/#{producer.slug}"
      }.to change(ProducerRegion, :count).by(-1)
           .and change(ProducerGrape, :count).by(-1)
    end

    it "purges the ActiveStorage attachments" do
      expect {
        delete "/api/v1/producers/#{producer.slug}"
      }.to change(ActiveStorage::Attachment, :count)
      expect(ActiveStorage::Attachment.where(record_id: producer.id).exists?).to be false
    end
  end

  describe "logo endpoint" do
    let!(:producer) { Producer.create!(producer_attributes.except(:region_ids, :grape_ids)) }

    before { sign_in super_user }

    it "attaches a valid logo and returns its url" do
      post "/api/v1/producers/#{producer.slug}/logo", params: { logo: logo_file }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["logo_url"]).to be_present
      expect(producer.reload.logo).to be_attached
    end

    it "replaces an existing logo" do
      producer.logo.attach(logo_file)
      first_id = producer.logo.blob.id

      post "/api/v1/producers/#{producer.slug}/logo", params: { logo: logo_file }
      expect(response).to have_http_status(:ok)
      expect(producer.reload.logo.blob.id).not_to eq(first_id)
    end

    it "rejects a missing logo" do
      post "/api/v1/producers/#{producer.slug}/logo"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects a non-image content type" do
      txt = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/logo.txt"), "text/plain"
      )
      post "/api/v1/producers/#{producer.slug}/logo", params: { logo: txt }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(producer.reload.logo).not_to be_attached
    end

    it "rejects an oversized logo" do
      big = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/big_logo.png"), "image/png"
      )
      post "/api/v1/producers/#{producer.slug}/logo", params: { logo: big }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(producer.reload.logo).not_to be_attached
    end

    it "removes the logo" do
      producer.logo.attach(logo_file)
      delete "/api/v1/producers/#{producer.slug}/logo"
      expect(response).to have_http_status(:no_content)
      expect(producer.reload.logo).not_to be_attached
    end
  end
end
