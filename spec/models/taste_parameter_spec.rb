require 'rails_helper'

# Model specs for the `generate_slug` callback on TasteParameter.
#
# TasteParameter drives the React finder's sliders (acidity, body,
# tannin, etc.). The serializer emits `id: taste_parameter.slug`, so
# the auto-slug has to be predictable across create and update.
RSpec.describe TasteParameter, type: :model do
  let(:five_labels) do
    { label_1: "Low", label_2: "Medium (-)", label_3: "Medium", label_4: "Medium (+)", label_5: "High" }
  end

  describe "five-level labels" do
    it "requires every label level" do
      parameter = TasteParameter.new(label: "Acidity", **five_labels.except(:label_3))

      expect(parameter).not_to be_valid
      expect(parameter.errors[:label_3]).to include("can't be blank")
    end

    it "resolves only whole-number scores from 1 through 5" do
      parameter = TasteParameter.new(label: "Acidity", **five_labels)

      expect(parameter.label_for(4)).to eq("Medium (+)")
      expect(parameter.label_for("5")).to eq("High")
      expect(parameter.label_for(0)).to be_nil
      expect(parameter.label_for(6)).to be_nil
      expect(parameter.label_for("four")).to be_nil
      expect(parameter.labels).to eq({ "1" => "Low", "2" => "Medium (-)", "3" => "Medium", "4" => "Medium (+)", "5" => "High" })
    end
  end

  describe "#generate_slug callback" do
    context "when the label is blank" do
      it "leaves the slug nil" do
        tp = TasteParameter.new(label: "", help: "h", **five_labels)
        tp.valid?
        expect(tp.slug).to be_nil
      end
    end

    context "when the label is provided and the slug is blank" do
      it "parameterizes the label into the slug" do
        tp = TasteParameter.create!(label: "Acidity", help: "Bright.", **five_labels)
        expect(tp.slug).to eq("acidity")
      end

      it "strips punctuation and downcases" do
        tp = TasteParameter.create!(label: "Alcohol %", help: "Heat.", **five_labels)
        expect(tp.slug).to eq("alcohol")
      end
    end

    context "when the caller has already set a slug" do
      it "does not overwrite the explicit slug" do
        tp = TasteParameter.create!(slug: "acid", label: "Acidity", help: "x", **five_labels)
        expect(tp.slug).to eq("acid")
      end
    end

    context "when the desired slug is already taken" do
      it "appends a numeric suffix" do
        TasteParameter.create!(slug: "body", label: "Body Original", help: "x", **five_labels)
        second = TasteParameter.create!(label: "Body", help: "x", **five_labels)
        expect(second.slug).to eq("body-2")
      end

      it "increments past existing -2, -3..." do
        TasteParameter.create!(slug: "tan", label: "A", help: "x", **five_labels)
        TasteParameter.create!(slug: "tan-2", label: "B", help: "x", **five_labels)
        TasteParameter.create!(slug: "tan-3", label: "C", help: "x", **five_labels)
        fourth = TasteParameter.create!(label: "Tan", help: "x", **five_labels)
        expect(fourth.slug).to eq("tan-4")
      end

      it "ignores the current record on update" do
        tp = TasteParameter.create!(label: "Sweet", help: "x", **five_labels)
        expect(tp.slug).to eq("sweet")
        tp.update!(help: "updated help text")
        expect(tp.reload.slug).to eq("sweet")
      end
    end

    context "on update" do
      it "does not regenerate the slug when the label changes" do
        tp = TasteParameter.create!(label: "Original", help: "x", **five_labels)
        original_slug = tp.slug
        tp.update!(label: "Renamed")
        expect(tp.reload.slug).to eq(original_slug)
      end
    end
  end
end
