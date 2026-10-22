require "rails_helper"

RSpec.describe ProducerMembership, type: :model do
  describe "associations" do
    it "belongs to user" do
      membership = ProducerMembership.new
      expect(membership).to respond_to(:user)
      expect(membership).to respond_to(:user=)
    end

    it "belongs to producer" do
      membership = ProducerMembership.new
      expect(membership).to respond_to(:producer)
      expect(membership).to respond_to(:producer=)
    end

    it "belongs to created_by (optional User)" do
      membership = ProducerMembership.new
      expect(membership).to respond_to(:created_by)
      expect(membership).to respond_to(:created_by=)
    end
  end

  describe "validations" do
    it "validates uniqueness of user_id scoped to producer_id" do
      user = User.create!(email: "test-#{SecureRandom.hex(4)}@example.com", password: "password123")
      producer = Producer.create!(name: "Test Producer #{SecureRandom.hex(4)}", slug: "test-producer-#{SecureRandom.hex(4)}")
      
      ProducerMembership.create!(user: user, producer: producer)
      duplicate = ProducerMembership.new(user: user, producer: producer)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("is already linked to this producer")
    end
  end
end