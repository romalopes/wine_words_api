require "rails_helper"

RSpec.describe Subscription, type: :model do
  before do
    load Rails.root.join("db/seeds/subscriptions.rb")
  end

  let(:free) { Subscription.find_by!(slug: "free") }
  let(:consumer) { Subscription.find_by!(slug: "consumer") }
  let(:retail) { Subscription.find_by!(slug: "retail") }

  describe "hierarchy" do
    it "orders plans by rank" do
      expect(Subscription.by_position.map(&:slug)).to eq(
        %w[free consumer trade distributor retail]
      )
    end

    it "detects higher/lower rank via explicit rank, not price" do
      expect(retail.higher_rank_than?(free)).to be true
      expect(free.lower_rank_than?(retail)).to be true
      expect(consumer.higher_rank_than?(consumer)).to be false
      expect(consumer.higher_rank_than?(nil)).to be false
    end
  end

  describe "validation" do
    it "rejects a negative rank" do
      sub = Subscription.new(name: "x", slug: "x", currency: "AUD", rank: -1)
      expect(sub).to be_invalid
    end
  end
end