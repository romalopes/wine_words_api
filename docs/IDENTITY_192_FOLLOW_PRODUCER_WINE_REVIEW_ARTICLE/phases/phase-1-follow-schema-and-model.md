# Phase 1 — Follow Schema and Model

**Status:** In Progress  
**Date:** 2026-10-25  

---

## 1. Migration: Create Follows Table

**File:** `db/migrate/20261025000001_create_follows.rb`

```ruby
class CreateFollows < ActiveRecord::Migration[7.2]
  def change
    create_table :follows do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :followable_type, null: false
      t.bigint :followable_id, null: false
      t.timestamps
    end

    add_index :follows, [:user_id, :followable_type, :followable_id],
              unique: true, name: :index_follows_on_user_and_followable
    add_index :follows, [:followable_type, :followable_id, :user_id],
              name: :index_follows_on_followable_and_user

    # Check constraint for allowed followable types
    execute <<-SQL
      ALTER TABLE follows
      ADD CONSTRAINT follows_followable_type_check
      CHECK (followable_type IN ('Producer', 'Wine', 'Review', 'Article'));
    SQL
  end
end
```

---

## 2. Follow Model

**File:** `app/models/follow.rb`

```ruby
class Follow < ApplicationRecord
  ALLOWED_TYPES = %w[Producer Wine Review Article].freeze

  belongs_to :user
  belongs_to :followable, polymorphic: true

  validates :followable_type, inclusion: { in: ALLOWED_TYPES }
  validates :user_id, uniqueness: { scope: [:followable_type, :followable_id] }

  scope :for_type, ->(type) { where(followable_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Ensure followable exists and is followable (published for Review/Article)
  validate :followable_is_visible

  private

  def followable_is_visible
    return unless followable

    case followable
    when Review, Article
      unless followable.visible_to(user).exists?
        errors.add(:followable, "is not visible to you")
      end
    when Producer
---

## 3. Model Associations

### User (`app/models/user.rb`)
```ruby
# Add to existing associations:
has_many :follows, dependent: :destroy
has_many :followed_producers, through: :follows, source: :followable, source_type: 'Producer'
has_many :followed_wines, through: :follows, source: :followable, source_type: 'Wine'
has_many :followed_reviews, through: :follows, source: :followable, source_type: 'Review'
has_many :followed_articles, through: :follows, source: :followable, source_type: 'Article'
```

### Producer (`app/models/producer.rb`)
```ruby
# Add to existing associations:
has_many :follows, as: :followable, dependent: :destroy
has_many :followers, through: :follows, source: :user
```

### Wine (`app/models/wine.rb`)
```ruby
# Add to existing associations:
has_many :follows, as: :followable, dependent: :destroy
has_many :followers, through: :follows, source: :user
```

### Review (`app/models/review.rb`)
```ruby
# Add to existing associations:
has_many :follows, as: :followable, dependent: :destroy
has_many :followers, through: :follows, source: :user
```

### Article (`app/models/article.rb`)
```ruby
# Add to existing associations:
has_many :follows, as: :followable, dependent: :destroy
has_many :followers, through: :follows, source: :user
```

---

## 4. Test Specification

**File:** `spec/models/follow_spec.rb`

```ruby
require "rails_helper"

RSpec.describe Follow, type: :model do
  let(:user) { create(:user) }
  let(:producer) { create(:producer) }
  let(:wine) { create(:wine, producer: producer) }
  let(:vintage) { create(:vintage, wine: wine) }
  let(:review) { create(:review, vintage: vintage, user: user, status: :published) }
  let(:article) { create(:article, user: user, status: :published) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:followable) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:followable_type) }
    it { is_expected.to validate_presence_of(:followable_id) }

    it "allows only Producer, Wine, Review, Article" do
      follow = build(:follow, followable_type: "Producer", followable: producer)
      expect(follow).to be_valid

      follow = build(:follow, followable_type: "Wine", followable: wine)
      expect(follow).to be_valid

      follow = build(:follow, followable_type: "Review", followable: review)
      expect(follow).to be_valid

      follow = build(:follow, followable_type: "Article", followable: article)
      expect(follow).to be_valid

      follow = build(:follow, followable_type: "Vintage", followable: vintage)
      expect(follow).not_to be_valid
      expect(follow.errors[:followable_type]).to be_present
    end

    it "prevents duplicate follows for same user and target" do
      create(:follow, user: user, followable: producer)
      duplicate = build(:follow, user: user, followable: producer)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end

    it "allows different users to follow same target" do
      other_user = create(:user)
      create(:follow, user: user, followable: producer)
      other_follow = build(:follow, user: other_user, followable: producer)
      expect(other_follow).to be_valid
    end

    it "allows same user to follow different targets" do
      create(:follow, user: user, followable: producer)
      other_follow = build(:follow, user: user, followable: wine)
      expect(other_follow).to be_valid
    end
  end

  describe "visibility validation" do
    it "allows following a published review" do
      follow = build(:follow, user: user, followable: review)
      expect(follow).to be_valid
    end

    it "rejects following a draft review by another user" do
      draft_review = create(:review, vintage: vintage, user: create(:user), status: :draft)
      follow = build(:follow, user: user, followable: draft_review)
      expect(follow).not_to be_valid
    end

    it "allows author to follow their own draft review" do
      draft_review = create(:review, vintage: vintage, user: user, status: :draft)
      follow = build(:follow, user: user, followable: draft_review)
      expect(follow).to be_valid
    end

    it "allows wine_manager to follow any review" do
      manager = create(:user, :wine_manager)
      draft_review = create(:review, vintage: vintage, user: create(:user), status: :draft)
      follow = build(:follow, user: manager, followable: draft_review)
      expect(follow).to be_valid
describe "scopes" do
    before do
      create(:follow, user: user, followable: producer)
      create(:follow, user: user, followable: wine)
      create(:follow, user: user, followable: review)
      create(:follow, user: user, followable: article)
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
      follow = create(:follow, user: user, followable: producer)
      user.destroy
      expect(Follow.exists?(follow.id)).to be false
    end

    it "destroys follows when followable is destroyed" do
      follow = create(:follow, user: user, followable: producer)
      producer.destroy
      expect(Follow.exists?(follow.id)).to be false
    end
  end

  describe "concurrency" do
    it "prevents duplicate follows under concurrent requests" do
      # Simulate race condition with two threads
      threads = 2.times.map do
        Thread.new { Follow.create!(user: user, followable: producer) }
      end
      results = threads.map(&:value)
      successes = results.select { |r| r.is_a?(Follow) }
      expect(successes.count).to eq(1)
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
```

---

## 5. Factory

**File:** `spec/factories/follows.rb`

```ruby
FactoryBot.define do
  factory :follow do
    association :user
    association :followable, factory: :producer

    trait :for_wine do
      association :followable, factory: :wine
    end

    trait :for_review do
      association :followable, factory: :review
    end

    trait :for_article do
      association :followable, factory: :article
    end
  end
end
```

---

## 6. Commands

```bash
cd /Users/romalopes/Documents/studies/my_project/wine_project/wine_words_api

# Generate migration
bin/rails generate migration CreateFollows

# Edit the generated migration per the schema above

# Run migration
bin/rails db:migrate

# Verify migration status
bin/rails db:migrate:status

# Run model tests
bundle exec rspec spec/models/follow_spec.rb

# Run full suite to ensure no regressions
bundle exec rspec spec/models/producer_membership_spec.rb
```

---

## 7. Gate: Phase 1 Complete

- [ ] Migration created and run
- [ ] Follow model implemented with validations
- [ ] Associations added to User, Producer, Wine, Review, Article
- [ ] Model tests pass
- [ ] ProducerMembership regression test passes
- [ ] No existing tests broken
    end
  end
      # Producers are always followable if they exist
    when Wine
      # Wines are always followable if they exist
    end
  end
end
```