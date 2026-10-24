require "rails_helper"

RSpec.describe ProducerMembership, type: :model do
  def create_user
    User.create!(email: "membership-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  let(:admin) { create_user }
  let(:user) { create_user }
  let(:producer) { Producer.create!(name: "Membership Producer #{SecureRandom.hex(4)}") }

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

      without_creator = ProducerMembership.create!(
        user: user, producer: producer, membership_type: "owner"
      )
      expect(without_creator.created_by).to be_nil

      with_creator = ProducerMembership.create!(
        user: create_user, producer: producer, membership_type: "manager", created_by: admin
      )
      expect(with_creator.created_by).to eq(admin)
    end
  end

  describe "membership_type" do
    it "accepts owner, manager and contributor" do
      ProducerMembership::MEMBERSHIP_TYPES.each_with_index do |type, index|
        membership = ProducerMembership.new(
          user: create_user,
          producer: Producer.create!(name: "Typed Producer #{index} #{SecureRandom.hex(3)}"),
          membership_type: type
        )
        expect(membership).to be_valid, "#{type} should be valid: #{membership.errors.full_messages}"
      end
    end

    it "rejects follower and viewer (no follow relationship in this release)" do
      %w[follower viewer].each do |type|
        membership = ProducerMembership.new(user: user, producer: producer, membership_type: type)
        expect(membership).not_to be_valid
        expect(membership.errors[:membership_type]).to include("must be owner, manager, or contributor")
      end
    end

    it "requires a type" do
      membership = ProducerMembership.new(user: user, producer: producer, membership_type: nil)
      expect(membership).not_to be_valid
      expect(membership.errors[:membership_type]).to include("can't be blank")
    end

    it "is enforced by a database check constraint" do
      membership = ProducerMembership.create!(user: user, producer: producer, membership_type: "owner")
      expect {
        membership.update_column(:membership_type, "follower")
      }.to raise_error(ActiveRecord::StatementInvalid, /chk_membership_type/)
    end
  end

  describe "validations" do
    it "validates uniqueness of user_id scoped to producer_id" do
      ProducerMembership.create!(user: user, producer: producer, membership_type: "owner")
      duplicate = ProducerMembership.new(user: user, producer: producer, membership_type: "manager")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("is already linked to this producer")
    end

    it "allows the same user to belong to different producers" do
      other_producer = Producer.create!(name: "Other Producer #{SecureRandom.hex(3)}")
      ProducerMembership.create!(user: user, producer: producer, membership_type: "owner")
      expect(
        ProducerMembership.new(user: user, producer: other_producer, membership_type: "contributor")
      ).to be_valid
    end
  end

  describe "type helpers" do
    it "reports the membership type" do
      owner = ProducerMembership.new(membership_type: "owner")
      expect(owner).to be_owner
      expect(owner).not_to be_manager
      expect(owner).not_to be_contributor
    end

    it "allows owners and managers to edit the producer" do
      expect(ProducerMembership.new(membership_type: "owner")).to be_can_edit_producer
      expect(ProducerMembership.new(membership_type: "manager")).to be_can_edit_producer
    end

    it "treats contributors as read-only" do
      expect(ProducerMembership.new(membership_type: "contributor")).not_to be_can_edit_producer
    end
  end

  describe "scopes" do
    it "filters by membership type" do
      owner = ProducerMembership.create!(user: create_user, producer: producer, membership_type: "owner")
      manager = ProducerMembership.create!(user: create_user, producer: producer, membership_type: "manager")
      contributor = ProducerMembership.create!(user: create_user, producer: producer, membership_type: "contributor")

      expect(ProducerMembership.owners).to include(owner)
      expect(ProducerMembership.owners).not_to include(manager, contributor)
      expect(ProducerMembership.managers).to include(manager)
      expect(ProducerMembership.managers).not_to include(owner, contributor)
      expect(ProducerMembership.contributors).to include(contributor)
      expect(ProducerMembership.contributors).not_to include(owner, manager)
    end
  end
end
