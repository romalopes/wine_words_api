require "rails_helper"

RSpec.describe Producer, type: :model do
  let!(:australia) do
    Country.find_by(code: "AU") ||
      Country.create!(name: "Australia", code: "AU", continent: "Oceania", flag_emoji: "🇦🇺")
  end
  let(:new_zealand) do
    Country.create!(name: "New Zealand", code: "NZ", continent: "Oceania", flag_emoji: "🇳🇿")
  end
  let(:region) { Region.create!(name: "South Australia", country: australia) }
  let(:grape) { Grape.create!(name: "Shiraz", color: "red") }

  def build_producer(attrs = {})
    Producer.new({ name: "Test Producer", email: "t@example.com" }.merge(attrs))
  end

  describe "validations" do
    it "defaults the country to Australia when blank" do
      producer = build_producer
      expect(producer).to be_valid
      expect(producer.country).to eq(australia)
    end

    it "accepts a founded year in the past" do
      expect(build_producer(founded_year: 1850)).to be_valid
    end

    it "accepts a founded year equal to the current year" do
      expect(build_producer(founded_year: Date.current.year)).to be_valid
    end

    it "rejects a future founded year" do
      expect(build_producer(founded_year: Date.current.year + 1)).not_to be_valid
    end

    it "rejects a non-positive founded year" do
      expect(build_producer(founded_year: 0)).not_to be_valid
    end

    it "allows a blank founded year" do
      expect(build_producer(founded_year: nil)).to be_valid
    end

    it "rejects regions outside the producer's country" do
      foreign = Region.create!(name: "Marlborough", country: new_zealand)
      producer = build_producer
      producer.regions << foreign
      expect(producer).not_to be_valid
      expect(producer.errors[:regions].join).to match(/country/i)
    end
  end

  describe "changing the country" do
    it "removes all producer regions" do
      producer = build_producer
      producer.save!
      producer.regions << region
      expect(producer.producer_regions.count).to eq(1)

      producer.update!(country: new_zealand, region_ids: [])
      expect(producer.reload.producer_regions).to be_empty
      expect(producer.regions).to be_empty
    end
  end

  describe "associations" do
    it "destroys join records with the producer" do
      producer = build_producer
      producer.save!
      producer.regions << region
      producer.grapes << grape

      expect { producer.destroy }
        .to change(ProducerRegion, :count).by(-1)
        .and change(ProducerGrape, :count).by(-1)
    end
  end

  describe "logo attachment" do
    it "rejects a non-image logo" do
      file = fixture_file_upload("spec/fixtures/files/logo.txt", "text/plain")
      producer = build_producer
      producer.save!
      producer.logo.attach(file)
      expect(producer).not_to be_valid
      expect(producer.errors[:logo].join).to match(/image/i)
    end
  end

  describe "default email" do
    it "generates an email from the slug when none is provided" do
      producer = build_producer(name: "Dandelion Vineyards", email: nil)
      producer.save!
      expect(producer.email).to eq("dandelion_vineyards@winewords.com.au")
    end

    it "generates an email from a single-word slug" do
      producer = build_producer(name: "Pedlidis", email: nil)
      producer.save!
      expect(producer.email).to eq("pedlidis@winewords.com.au")
    end

    it "preserves an explicitly provided email" do
      producer = build_producer(email: "winery@example.com")
      producer.save!
      expect(producer.email).to eq("winery@example.com")
    end
  end

  describe "deleting a producer" do
    it "reassigns its wines to the Unknown Producer" do
      producer = build_producer
      producer.save!
      wine = Wine.create!(name: "Test Wine", color: "Red", producer: producer)

      expect { producer.destroy }
        .to change { wine.reload.producer_id }
        .to(Producer.unknown_producer.id)
      expect(Producer).not_to exist(producer.id)
    end

    it "still leaves the wines valid (producer never nil)" do
      producer = build_producer
      producer.save!
      wine = Wine.create!(name: "Test Wine", color: "Red", producer: producer)

      producer.destroy

      expect(wine.reload.producer).to eq(Producer.unknown_producer)
      expect(wine).to be_valid
    end

    it "creates the shared Unknown Producer with a valid auto-generated email" do
      unknown = Producer.unknown_producer
      expect(unknown.email).to eq("unknown_producer@winewords.com.au")
      expect(unknown).to be_valid
    end
  end
end
