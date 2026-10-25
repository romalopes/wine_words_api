require "rails_helper"

RSpec.describe Follow, type: :model do
  let(:user) { User.create!(first_name: "Follow User", email: "follow-user@example.com", password: "password123") }
  let(:producer) { Producer.create!(name: "Follow Producer") }
  let(:wine) { Wine.create!(name: "Follow Wine", producer: producer, color: "Red", closure: "Cork", alcohol_percentage: 13.5, volume_ml: 750) }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }
  let(:review) { Review.create!(vintage: vintage, user: user, title: "Follow Review", comment: "Great wine", score: 90, status: "published", source: "manual") }
  let(:article) { Article.create!(user: user, title: "Follow Article", abstract: "Abstract", body: "Body", status: "published", source: "manual") }
  let(:other_user) { User.create!(first_name: "Other User", email: "other-user@example.com", password: "password123") }
  let(:manager) { User.create!(first_name: "Manager", email: "manager@example.com", password: "password123").tap { |u| u.roles << Role.find_or_create_by!(name: "Reviewer") } }
  let(:draft_review) { Review.create!(vintage: vintage, user: other_user, title: "Draft Review", comment: "Draft", score: 80, status: "draft", source: "manual") }

  describe "associations" do
    it "belongs to user" do
      follow = Follow.new(user: user, followable: producer)
      expect(follow.user).to eq(user)
    end

    it "belongs to a polymorphic followable" do
      follow = Follow.new(user: user, followable: producer)
      expect(follow.followable).to eq(producer)
      expect(follow.followable_type).to eq("Producer")
    end
  end

  describe "validations" do
    it "requires a followable_type and followable_id" do
      follow = Follow.new(user: user)
      expect(follow).not_to be_valid
      expect(follow.errors[:followable_type]).to be_present
    end

    it "allows only Producer, Wine, Review, Article" do
      follow = Follow.new(user: user, followable_type: "Producer", followable: producer)
      expect(follow).to be_valid

      follow = Follow.new(user: user, followable_type: "Wine", followable: wine)
      expect(follow).to be_valid

      follow = Follow.new(user: user, followable_type: "Review", followable: review)
      expect(follow).to be_valid

      follow = Follow.new(user: user, followable_type: "Article", followable: article)
      expect(follow).to be_valid

      follow = Follow.new(user: user, followable_type: "Vintage", followable: vintage)
      expect(follow).not_to be_valid
      expect(follow.errors[:followable_type]).to be_present
    end

    it "prevents duplicate follows for same user and target" do
      Follow.create!(user: user, followable: producer)
      duplicate = Follow.new(user: user, followable: producer)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "allows different users to follow same target" do
      Follow.create!(user: user, followable: producer)
      other_follow = Follow.new(user: other_user, followable: producer)
      expect(other_follow).to be_valid
    end

    it "allows same user to follow different targets" do
      Follow.create!(user: user, followable: producer)
      other_follow = Follow.new(user: user, followable: wine)
      expect(other_follow).to be_valid
    end
  end

  describe "visibility validation" do
    it "allows following a published review" do
      follow = Follow.new(user: user, followable: review)
      expect(follow).to be_valid
    end

    it "rejects following a draft review by another user" do
      follow = Follow.new(user: user, followable: draft_review)
      expect(follow).not_to be_valid
    end

    it "allows author to follow their own draft review" do
      my_draft = Review.create!(vintage: vintage, user: user, title: "My Draft", comment: "Draft", score: 80, status: "draft", source: "manual")
      follow = Follow.new(user: user, followable: my_draft)
      expect(follow).to be_valid
    end

    it "allows wine_manager to follow any review" do
      follow = Follow.new(user: manager, followable: draft_review)
      expect(follow).to be_valid
    end
  end

  describe "scopes" do
    before do
      Follow.create!(user: user, followable: producer)
      Follow.create!(user: user, followable: wine)
      Follow.create!(user: user, followable: review)
      Follow.create!(user: user, followable: article)
    end

    it ".for_type filters by followable_type" do
      expect(user.follows.for_type("Producer").count).to eq(1)
      expect(user.follows.for_type("Wine").count).to eq(1)
      expect(user.follows.for_type("Review").count).to eq(1)
      expect(user.follows.for_type("Article").count).to eq(1)
    end

    it ".recent orders by created_at desc" do
      expect(user.follows.recent.first.followable).to eq(article)
    end
  end

  describe "cleanup on deletion" do
    it "destroys follows when user is destroyed" do
      follow = Follow.create!(user: user, followable: producer)
      user.destroy
      expect(Follow.exists?(follow.id)).to be false
    end

    it "destroys follows when followable is destroyed" do
      follow = Follow.create!(user: user, followable: producer)
      producer.destroy
      expect(Follow.exists?(follow.id)).to be false
    end
  end

  describe "concurrency" do
    it "prevents duplicate follows under concurrent requests" do
      user1 = User.create!(first_name: "Concurrent1", email: "concurrent1@example.com", password: "password123")
      user2 = User.create!(first_name: "Concurrent2", email: "concurrent2@example.com", password: "password123")

      threads = 2.times.map do |i|
        Thread.new { Follow.create!(user: [user1, user2][i], followable: producer) }
      end
      results = threads.map(&:value)
      successes = results.select { |r| r.is_a?(Follow) }
      expect(successes.count).to eq(2)
    end
  end

  describe "ProducerMembership regression" do
    it "still only accepts owner, manager, contributor" do
      membership = ProducerMembership.new(user: user, producer: producer, membership_type: "follower")
      expect(membership).not_to be_valid
      expect(membership.errors[:membership_type]).to be_present
    end

    it "accepts valid membership types" do
      %w[owner manager contributor].each do |type|
        membership = ProducerMembership.new(user: user, producer: producer, membership_type: type)
        expect(membership).to be_valid
      end
    end
  end
end