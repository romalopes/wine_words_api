require "rails_helper"

# The trade views must show the wine the Wine Words team actually resolved a
# submitted line to, while keeping the submitter's original snapshot intact.
RSpec.describe TradePackageSerializer do
  let(:producer) { Producer.create!(name: "Nepenthe") }
  let(:wine) do
    Wine.create!(name: "Nepenthe Altitude Sauvignon Blanc", color: "White", producer: producer)
  end
  let(:vintage) { Vintage.create!(wine: wine, year: 2026) }

  let(:package) do
    WinePackage.create!(
      source: "trade_submission",
      status: "editorial_pending",
      contact_snapshot: {
        "company_name" => "Bodega Ejemplo",
        "contact_name" => "Maria Ruiz",
        "email" => "maria@bodega-ejemplo.es"
      }
    )
  end

  let!(:item) do
    package.wine_package_items.create!(
      quantity: 1,
      proposed_wine_name: "Altitude Sauvignon Blanc",
      proposed_vintage_year: 2026
    )
  end

  def item_json(viewer:)
    described_class.new(package.reload, nil, viewer: viewer).as_json[:items].first
  end

  describe "before the catalogue match" do
    it "reports the submitted snapshot and no resolved match" do
      row = item_json(viewer: :submitter)

      expect(row[:wine_name]).to eq("Altitude Sauvignon Blanc")
      expect(row[:vintage]).to eq("2026")
      expect(row[:resolved]).to be(false)
      expect(row[:catalogue_wine_id]).to be_nil
      expect(row[:catalogue_wine_name]).to be_nil
      expect(row[:vintage_id]).to be_nil
    end
  end

  describe "after the Wine Words team links a wine + vintage" do
    before { item.update!(vintage: vintage) }

    it "keeps the submitter's snapshot untouched" do
      row = item_json(viewer: :submitter)

      expect(row[:wine_name]).to eq("Altitude Sauvignon Blanc")
      expect(row[:vintage]).to eq("2026")
    end

    it "exposes the resolved catalogue wine, producer and vintage to the submitter" do
      row = item_json(viewer: :submitter)

      expect(row[:resolved]).to be(true)
      expect(row[:catalogue_wine_id]).to eq(wine.id)
      expect(row[:catalogue_wine_name]).to eq("Nepenthe Altitude Sauvignon Blanc")
      expect(row[:catalogue_wine_slug]).to eq(wine.slug)
      expect(row[:catalogue_producer_id]).to eq(producer.id)
      expect(row[:catalogue_producer_name]).to eq("Nepenthe")
      expect(row[:vintage_id]).to eq(vintage.id)
      expect(row[:vintage_year]).to eq(2026)
      expect(row[:vintage_label]).to eq("2026")
    end

    it "exposes the same resolved match to staff" do
      row = item_json(viewer: :staff)

      expect(row[:resolved]).to be(true)
      expect(row[:catalogue_wine_name]).to eq("Nepenthe Altitude Sauvignon Blanc")
      expect(row[:catalogue_producer_name]).to eq("Nepenthe")
      expect(row[:vintage_label]).to eq("2026")
    end

    it "links the catalogue wine on the item so admin matching stays consistent" do
      expect(item.reload.catalogue_wine_id).to eq(wine.id)
    end
  end

  describe "when the Wine Words team adds a catalogue line directly" do
    before do
      package.wine_package_items.create!(vintage: vintage, quantity: 2, review_requested: true)
    end

    it "falls back to the catalogue identity and marks the line as not submitted" do
      # The team-added line is the LAST item; the first one is the original
      # submitter's snapshot line from the enclosing spec.
      row = described_class.new(package.reload, nil, viewer: :submitter)
                           .as_json[:items].last

      expect(row[:wine_name]).to eq("Nepenthe Altitude Sauvignon Blanc")
      expect(row[:vintage]).to eq("2026")
      expect(row[:submitted]).to be(false)
      expect(row[:resolved]).to be(true)
      expect(row[:catalogue_wine_name]).to eq("Nepenthe Altitude Sauvignon Blanc")
      expect(row[:catalogue_producer_name]).to eq("Nepenthe")
      expect(row[:quantity]).to eq(2)
    end
  end
end
