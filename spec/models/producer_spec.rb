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
end
