require 'rails_helper'

# Model specs for the `generate_slug` callback on Wine.
#
# Wines are addressed by their slug in the public JSON API (the
# serializer emits `id: wine.slug`), so the auto-generation logic has
# to be reliable. These specs cover the four behaviours that matter:
# blank-name pass-through, simple parameterization, respect for an
# explicit slug, and disambiguation when the desired slug is already
# taken.
RSpec.describe Wine, type: :model do
  describe "#generate_slug callback" do
    context "when the name is blank" do
      it "leaves the slug nil (validation will reject the record)" do
        wine = Wine.new(name: "", region: "Anywhere", color: "Red", prompt: "x")
        expect { wine.valid? }.not_to change { wine.slug }
        expect(wine.slug).to be_nil
      end
    end

    context "when the name is provided and the slug is blank" do
      it "parameterizes the name into the slug" do
        wine = Wine.create!(
          name: "Penfolds Bin 389",
          region: "South Australia",
          color: "Red",
          prompt: "x",
        )
        expect(wine.slug).to eq("penfolds-bin-389")
      end

      it "strips punctuation and downcases" do
        wine = Wine.create!(
          name: "Château d'Yquem!",
          region: "Sauternes",
          color: "Dessert",
          prompt: "x",
        )
        # Rails' `parameterize` keeps alphanumerics, replaces every
        # other run with a single dash and trims trailing dashes.
        expect(wine.slug).to eq("chateau-d-yquem")
      end

      it "collapses runs of non-alphanumerics into single dashes" do
        wine = Wine.create!(
          name: "Foo  --  Bar   Baz",
          region: "Anywhere",
          color: "Red",
          prompt: "x",
        )
        expect(wine.slug).to eq("foo-bar-baz")
      end
    end

    context "when the caller has already set a slug" do
      it "does not overwrite the explicit slug" do
        wine = Wine.create!(
          slug: "custom-slug",
          name: "Some Wine",
          region: "Anywhere",
          color: "Red",
          prompt: "x",
        )
        expect(wine.slug).to eq("custom-slug")
      end
    end

    context "when the desired slug is already taken by another wine" do
      it "appends a numeric suffix to disambiguate" do
        Wine.create!(
          slug: "shared",
          name: "First Wine",
          region: "Anywhere",
          color: "Red",
          prompt: "x",
        )
        second = Wine.create!(
          name: "Shared",
          region: "Anywhere",
          color: "Red",
          prompt: "x",
        )
        expect(second.slug).to eq("shared-2")
      end

      it "increments the suffix until a free slug is found" do
        Wine.create!(slug: "crowded", name: "A", region: "x", color: "Red", prompt: "x")
        Wine.create!(slug: "crowded-2", name: "B", region: "x", color: "Red", prompt: "x")
        Wine.create!(slug: "crowded-3", name: "C", region: "x", color: "Red", prompt: "x")
        fourth = Wine.create!(name: "Crowded", region: "x", color: "Red", prompt: "x")
        expect(fourth.slug).to eq("crowded-4")
      end

      it "ignores the current record when checking for slug collisions" do
        wine = Wine.create!(name: "Round Trip", region: "x", color: "Red", prompt: "x")
        expect(wine.slug).to eq("round-trip")
        # Updating the same record and saving again should not push
        # the slug to `round-trip-2` - the callback's `where.not(id: id)`
        # filter prevents that.
        wine.update!(prompt: "new prompt")
        expect(wine.reload.slug).to eq("round-trip")
      end
    end

        context "on update" do
      it "does not regenerate the slug when the name changes" do
        wine = Wine.create!(name: "Original Name", region: "x", color: "Red", prompt: "x")
        original_slug = wine.slug
        wine.update!(name: "A Completely Different Name")
        expect(wine.reload.slug).to eq(original_slug)
      end
    end
  end

  describe "volume selection" do
    it "exposes 750ml as the default volume" do
      expect(Wine::DEFAULT_VOLUME).to eq(750)
      expect(Wine.volume_values).to include(750)
    end

    it "accepts every known bottle size" do
      Wine.volume_values.each do |ml|
        wine = Wine.new(name: "T", region: "R", color: "Red", volume_ml: ml, prompt: "x")
        expect(wine).to be_valid
      end
    end

    it "rejects an unknown bottle size" do
      wine = Wine.new(name: "T", region: "R", color: "Red", volume_ml: 999, prompt: "x")
      expect(wine).not_to be_valid
            expect(wine.errors[:volume_ml]).to be_present
    end

    it "defaults a blank volume to 750ml (never persisted blank)" do
      wine = Wine.new(name: "T", region: "R", color: "Red", volume_ml: nil, prompt: "x")
      expect(wine.volume_ml).to eq(Wine::DEFAULT_VOLUME)
      expect(wine).to be_valid
    end

    it "returns a human label for a known volume" do
      wine = Wine.new(name: "T", region: "R", color: "Red", volume_ml: 1500, prompt: "x")
      expect(wine.volume_label).to eq("1.5 L")
    end

    it "keeps volume as an integer in the database column" do
      wine = Wine.create!(name: "T", region: "R", color: "Red", volume_ml: 750, prompt: "x")
      expect(wine.volume_ml).to be_an(Integer)
    end
  end

  describe "required defaults" do
    it "defaults colour to 'White'" do
      expect(Wine.new.color).to eq("White")
    end

    it "defaults closure to 'Cork'" do
      expect(Wine.new.closure).to eq("Cork")
    end

    it "defaults alcohol_percentage to 13.5" do
      expect(Wine.new.alcohol_percentage.to_f).to eq(13.5)
    end

    it "defaults volume_ml to 750" do
      expect(Wine.new.volume_ml).to eq(750)
    end

    it "rejects an invalid closure" do
      wine = Wine.new(name: "T", region: "R", color: "Red", closure: "Bogus", prompt: "x")
      expect(wine).not_to be_valid
      expect(wine.errors[:closure]).to be_present
    end

    it "rejects a blank name even when other fields default" do
      wine = Wine.new(name: "", region: "R")
      expect(wine).not_to be_valid
      expect(wine.errors[:name]).to be_present
    end
  end
end
