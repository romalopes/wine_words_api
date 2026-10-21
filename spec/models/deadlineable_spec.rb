require "rails_helper"

# Issue #185 — publication deadlines for Articles and Reviews.
#
# The interesting behaviour is in the model layer: the 14-day fallback, the
# draft-only `overdue?` definition, and the Review inheritance chain
# (explicit > WinePackage > Article > fallback).
RSpec.describe "Publication deadlines", type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:author) do
    User.create!(first_name: "Deadline Author", email: "deadline-author@example.com",
                 password: "password123")
  end
  let(:producer) { Producer.create!(name: "Deadline Producer") }
  let(:wine) { Wine.create!(name: "Deadline Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2020) }

  # A fixed "today" so Date.current is deterministic across the suite.
  around do |example|
    travel_to(Time.zone.local(2026, 10, 21, 10, 0)) { example.run }
  end

  def today = Date.new(2026, 10, 21)

  def create_article(attrs = {})
    Article.create!({ title: "Deadline article", status: "draft", user: author }.merge(attrs))
  end

  def create_review(attrs = {})
    Review.create!(
      { title: "Deadline review", score: 90, status: "draft", user: author,
        vintage: vintage }.merge(attrs)
    )
  end

  def create_package(attrs = {})
    WinePackage.create!(
      { producer: producer, reviewer: author, created_by: author,
        source: "unexpected" }.merge(attrs)
    )
  end

  describe Article do
    it "defaults a new article to 14 days from today" do
      expect(create_article.deadline).to eq(today + 14)
    end

    it "keeps an explicitly supplied deadline" do
      article = create_article(deadline: today + 3)

      expect(article.deadline).to eq(today + 3)
    end

    it "leaves a legacy null deadline null and never flags it overdue" do
      article = create_article
      article.update_column(:deadline, nil)

      expect(article.reload.deadline).to be_nil
      expect(article.overdue?).to be(false)
      expect(article.days_until_deadline).to be_nil
    end

    it "is overdue only when a draft deadline is earlier than today" do
      expect(create_article(deadline: today - 1).overdue?).to be(true)
      expect(create_article(deadline: today).overdue?).to be(false)
      expect(create_article(deadline: today + 1).overdue?).to be(false)
    end

    it "is never overdue once published or archived, but keeps the date" do
      published = create_article(deadline: today - 5, status: "published")
      archived = create_article(deadline: today - 5, status: "archived")

      expect(published.overdue?).to be(false)
      expect(archived.overdue?).to be(false)
      expect(published.deadline).to eq(today - 5)
      expect(archived.deadline).to eq(today - 5)
    end

    it "clears overdue on publish without deleting the stored date" do
      article = create_article(deadline: today - 2)
      expect(article.overdue?).to be(true)

      article.update!(status: "published")

      expect(article.overdue?).to be(false)
      expect(article.deadline).to eq(today - 2)
    end

    it "reports signed days until the deadline" do
      expect(create_article(deadline: today - 2).days_until_deadline).to eq(-2)
      expect(create_article(deadline: today).days_until_deadline).to eq(0)
      expect(create_article(deadline: today + 2).days_until_deadline).to eq(2)
    end

    it "does not reset the deadline on update" do
      article = create_article(deadline: today + 2)

      article.update!(title: "Renamed")

      expect(article.reload.deadline).to eq(today + 2)
    end
  end


  describe Review do
    it "defaults a standalone review to 14 days from today" do
      expect(create_review.deadline).to eq(today + 14)
    end

    it "keeps an explicit deadline above every source" do
      article = create_article(deadline: today + 1)
      review = create_review(deadline: today + 9)
      ArticleReview.create!(article: article, review: review, status: "draft")

      expect(review.deadline).to eq(today + 9)
    end

    it "inherits the WinePackage deadline through the creation service" do
      package = create_package(review_deadline: today + 5)
      item = package.wine_package_items.create!(vintage: vintage, quantity: 1,
                                                review_requested: true)

      review = WinePackages::CreateReviewFromPackage.call(
        item, user: author, attributes: { title: "Package review", score: 90 }
      )

      expect(review.deadline).to eq(today + 5)
    end

    it "prefers an explicit deadline over the WinePackage deadline" do
      package = create_package(review_deadline: today + 5)
      item = package.wine_package_items.create!(vintage: vintage, quantity: 1,
                                                review_requested: true)

      review = WinePackages::CreateReviewFromPackage.call(
        item, user: author,
        attributes: { title: "Package review", score: 90, deadline: today + 2 }
      )

      expect(review.deadline).to eq(today + 2)
    end

    it "falls back to 14 days when the package has no deadline" do
      package = create_package
      item = package.wine_package_items.create!(vintage: vintage, quantity: 1,
                                                review_requested: true)

      review = WinePackages::CreateReviewFromPackage.call(
        item, user: author, attributes: { title: "Package review", score: 90 }
      )

      expect(review.deadline).to eq(today + 14)
    end

    it "resolves the linked Article deadline when no package is attached" do
      article = create_article(deadline: today + 4)
      review = create_review
      ArticleReview.create!(article: article, review: review, status: "draft")

      expect(review.reload.inherited_deadline).to eq(today + 4)
    end

    it "gives the WinePackage priority when both sources are attached" do
      article = create_article(deadline: today + 4)
      package = create_package(review_deadline: today + 8)
      review = create_review
      ArticleReview.create!(article: article, review: review, status: "draft")
      package.wine_package_items.create!(vintage: vintage, quantity: 1,
                                         review_requested: true, review: review)

      expect(review.reload.inherited_deadline).to eq(today + 8)
    end

    it "does not cascade a later source deadline change into the review" do
      package = create_package(review_deadline: today + 5)
      item = package.wine_package_items.create!(vintage: vintage, quantity: 1,
                                                review_requested: true)
      review = WinePackages::CreateReviewFromPackage.call(
        item, user: author, attributes: { title: "Package review", score: 90 }
      )

      package.update!(review_deadline: today + 20)

      expect(review.reload.deadline).to eq(today + 5)
    end

    it "is overdue only while a draft is past its deadline" do
      expect(create_review(deadline: today - 1).overdue?).to be(true)
      expect(create_review(deadline: today).overdue?).to be(false)
      expect(create_review(deadline: today + 1).overdue?).to be(false)
      expect(create_review(deadline: today - 1, status: "published").overdue?).to be(false)
    end
  end

  describe "serialization" do
    it "exposes deadline, overdue and days_until_deadline for an article" do
      article = create_article(deadline: today - 1)

      payload = ArticleListSerializer.new(article).as_json

      expect(payload[:deadline]).to eq("2026-10-20")
      expect(payload[:overdue]).to be(true)
      expect(payload[:days_until_deadline]).to eq(-1)
    end

    it "exposes deadline, overdue and days_until_deadline for a review" do
      review = create_review(deadline: today + 2)

      payload = ReviewSerializer.new(review).as_json

      expect(payload[:deadline]).to eq("2026-10-23")
      expect(payload[:overdue]).to be(false)
      expect(payload[:days_until_deadline]).to eq(2)
    end
  end
end
