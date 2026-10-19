require 'rails_helper'

# Model specs for the `generate_slug` callback on WineProfile.
#
# WineProfile is the canonical wine catalogue that the React finder
# reads. Its public-API `id` is the slug, so the callback has to be
# deterministic and collision-safe.
RSpec.describe WineProfile, type: :model do
  describe "#generate_slug callback" do
    context "when the name is blank" do
      it "leaves the slug nil" do
        profile = WineProfile.new(name: "", color: "Red")
        profile.valid?
        expect(profile.slug).to be_nil
      end
    end

    context "when the name is provided and the slug is blank" do
      it "parameterizes the name into the slug" do
        profile = WineProfile.create!(
          name: "Pinot Noir",
          color: "Red",
          notes: '["cherry"]',
          serving: "x",
        )
        expect(profile.slug).to eq("pinot-noir")
      end

      it "strips punctuation and downcases" do
        profile = WineProfile.create!(
          name: "Müller-Thurgau!",
          color: "White",
          notes: "[]",
          serving: "x",
        )
        expect(profile.slug).to eq("muller-thurgau")
      end
    end

    context "when the caller has already set a slug" do
      it "does not overwrite the explicit slug" do
        profile = WineProfile.create!(
          slug: "my-pinot",
          name: "Pinot Noir",
          color: "Red",
          notes: "[]",
          serving: "x",
        )
        expect(profile.slug).to eq("my-pinot")
      end
    end

    context "when the desired slug is already taken" do
      it "appends a numeric suffix" do
        WineProfile.create!(slug: "taken", name: "First", color: "Red", notes: "[]", serving: "x")
        second = WineProfile.create!(name: "Taken", color: "Red", notes: "[]", serving: "x")
        expect(second.slug).to eq("taken-2")
      end

      it "increments the suffix past existing -2, -3, -4..." do
        WineProfile.create!(slug: "full", name: "A", color: "Red", notes: "[]", serving: "x")
        WineProfile.create!(slug: "full-2", name: "B", color: "Red", notes: "[]", serving: "x")
        WineProfile.create!(slug: "full-3", name: "C", color: "Red", notes: "[]", serving: "x")
        fourth = WineProfile.create!(name: "Full", color: "Red", notes: "[]", serving: "x")
        expect(fourth.slug).to eq("full-4")
      end

      it "does not collide with the same record being updated" do
        profile = WineProfile.create!(name: "Identity", color: "Red", notes: "[]", serving: "x")
        expect(profile.slug).to eq("identity")
        profile.update!(serving: "updated serving")
        expect(profile.reload.slug).to eq("identity")
      end
    end

    context "on update" do
      it "does not regenerate the slug when the name changes" do
        profile = WineProfile.create!(name: "Original", color: "Red", notes: "[]", serving: "x")
        original_slug = profile.slug
        profile.update!(name: "Renamed")
        expect(profile.reload.slug).to eq(original_slug)
      end
    end
  end
end
