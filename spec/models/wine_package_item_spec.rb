require "rails_helper"

# Unit specs for WinePackageItem — one wine line inside a package.
#
# Two things matter here: "reviewed" is *derived* from the linked review (there
# is no stored flag), and the line's own changes are what trigger package
# completion or reopening through WinePackages::CheckCompletion.
RSpec.describe WinePackageItem, type: :model do
  let(:producer) { Producer.create!(name: "Phase F Item Producer") }
  let(:reviewer) { create_user("Phase F Item Reviewer", "phase-f-item-reviewer@example.com") }
  let(:other_user) { create_user("Phase F Item Other", "phase-f-item-other@example.com") }
  let(:wine) { Wine.create!(name: "Phase F Item Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2019) }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  # An arrived package: completion logic is active for it.
  def create_package(attrs = {})
    WinePackage.create!(
      {
        producer: producer,
        reviewer: reviewer,
        created_by: reviewer,
        source: "unexpected",
        status: "arrived",
        arrived_at: Time.current,
        review_deadline: Date.current + 30
      }.merge(attrs)
    )
  end

  def build_item(package, attrs = {})
    package.wine_package_items.new({ vintage: vintage, quantity: 1 }.merge(attrs))
  end

  def published_review(title)
    Review.create!(vintage: vintage, user: reviewer, title: title, score: 90,
                   status: "published")
  end

  def draft_review(title)
    Review.create!(vintage: vintage, user: reviewer, title: title, score: 88,
                   status: "draft")
  end

  describe "defaults and validations" do
    let(:package) { create_package }

    it "defaults to one bottle that was not requested for review" do
      item = build_item(package)

      expect(item.quantity).to eq(1)
      expect(item.review_requested).to be false
    end

    it "requires a package" do
      item = WinePackageItem.new(vintage: vintage, quantity: 1)

      expect(item).not_to be_valid
      expect(item.errors[:wine_package]).to be_present
    end

    it "accepts an item whose wine is not in the catalogue yet" do
      item = build_item(package, vintage: nil, review_requested: true)

      expect(item).to be_valid
      expect(item.save).to be true
    end

    it "rejects a zero, negative, fractional or missing quantity" do
      [ 0, -1, 1.5, nil ].each do |quantity|
        item = build_item(package, quantity: quantity)
        expect(item).not_to be_valid, "quantity #{quantity.inspect} should be invalid"
        expect(item.errors[:quantity]).to be_present
      end
    end

    it "accepts every positive whole quantity" do
      expect(build_item(package, quantity: 12)).to be_valid
    end

    it "allows the same vintage to appear twice in one package" do
      build_item(package, quantity: 2).save!
      build_item(package, quantity: 1).save!

      expect(package.wine_package_items.where(vintage: vintage).count).to eq(2)
    end

    it "allows the same vintage to appear in several packages" do
      other_package = create_package
      build_item(package).save!
      build_item(other_package).save!

      expect(WinePackageItem.where(vintage: vintage).count).to eq(2)
    end
  end

  describe "associations" do
    let(:package) { create_package }

    it "belongs to its package, an optional vintage and an optional review" do
      item = build_item(package, review: published_review("Phase F item assoc"))
      item.save!

      expect(item.wine_package).to eq(package)
      expect(item.vintage).to eq(vintage)
      expect(item.review).to be_present
    end

    it "is listed by the review it fulfilled" do
      item = build_item(package, review: published_review("Phase F item back ref"))
      item.save!

      expect(item.review.wine_package_items).to include(item)
    end

    it "detaches from its review when the review is deleted" do
      review = published_review("Phase F item detach")
      item = build_item(package, review: review)
      item.save!

      review.destroy

      expect(item.reload.review_id).to be_nil
      expect(item).to be_persisted
    end
  end

  describe "derived review state" do
    let(:package) { create_package }

    it "is not reviewed without a review" do
      item = build_item(package, review_requested: true)
      item.save!

      expect(item.reviewed?).to be false
      expect(item.reviewable?).to be true
      expect(item.pending_review?).to be true
    end

    it "is not reviewed while its review is a draft" do
      item = build_item(package, review_requested: true, review: draft_review("Phase F draft"))
      item.save!

      expect(item.reviewed?).to be false
      expect(item.pending_review?).to be true
    end

    it "is reviewed once its review is published" do
      item = build_item(package, review_requested: true,
                        review: published_review("Phase F published"))
      item.save!

      expect(item.reviewed?).to be true
      expect(item.pending_review?).to be false
    end

    it "never counts a line that was not requested for review" do
      item = build_item(package, review_requested: false)

      expect(item.reviewable?).to be false
      expect(item.pending_review?).to be false
    end
  end

  describe "#wine and #label" do
    let(:package) { create_package }

    it "names the wine and vintage it is matched to" do
      item = build_item(package)

      expect(item.wine).to eq(wine)
      expect(item.label).to eq("Phase F Item Wine 2019")
    end

    it "tolerates a line that is not matched to a wine yet" do
      item = build_item(package, vintage: nil)

      expect(item.wine).to be_nil
      expect(item.label).to eq("Unmatched wine")
    end
  end

  describe "scopes" do
    let(:package) { create_package }

    it "filters to the lines that were requested for review" do
      requested = build_item(package, review_requested: true).tap(&:save!)
      build_item(package, review_requested: false).save!

      expect(WinePackageItem.with_review_requested).to contain_exactly(requested)
    end

    it "filters to the lines fulfilled by a published review" do
      done = build_item(package, review_requested: true,
                        review: published_review("Phase F scope done")).tap(&:save!)
      build_item(package, review_requested: true,
                 review: draft_review("Phase F scope draft")).save!

      expect(WinePackageItem.reviewed).to contain_exactly(done)
    end

    it "filters to the requested lines that still need a published review" do
      no_review = build_item(package, review_requested: true).tap(&:save!)
      still_draft = build_item(package, review_requested: true,
                               review: draft_review("Phase F scope pending")).tap(&:save!)
      build_item(package, review_requested: true,
                 review: published_review("Phase F scope published")).save!
      build_item(package, review_requested: false).save!

      expect(WinePackageItem.pending_review).to contain_exactly(no_review, still_draft)
    end
  end

  describe "package completion triggered by its lines" do
    it "auto-completes an arrived package once its only requested line is published" do
      package = create_package
      build_item(package, review_requested: true,
                 review: published_review("Phase F auto complete")).save!

      package.reload
      expect(package.status).to eq("completed")
      expect(package.auto_completed).to be true
      expect(package.reviewed_at).to be_present
    end

    it "does not complete while a requested line still lacks a published review" do
      package = create_package
      build_item(package, review_requested: true).save!
      expect(package.reload.status).to eq("arrived")

      build_item(package, review_requested: true,
                 review: draft_review("Phase F still draft")).save!
      expect(package.reload.status).to eq("arrived")
    end

    it "does not complete a package whose lines were never requested for review" do
      package = create_package
      build_item(package, review_requested: false,
                 review: published_review("Phase F unrequested")).save!

      expect(package.reload.status).to eq("arrived")
    end

    it "reopens an auto-completed package when a new requested line arrives" do
      package = create_package
      build_item(package, review_requested: true,
                 review: published_review("Phase F reopen")).save!
      expect(package.reload.status).to eq("completed")

      build_item(package, review_requested: true).save!

      package.reload
      expect(package.status).to eq("reviewing")
      expect(package.auto_completed).to be false
      expect(package.pending_review_count).to eq(1)
    end

    it "completes when the last blocking line stops asking for a review" do
      package = create_package
      fulfilled = build_item(package, review_requested: true)
      fulfilled.save!
      blocker = build_item(package, review_requested: true)
      blocker.save!

      # Once the first line is fulfilled the blocker is the only thing left.
      fulfilled.update!(review: published_review("Phase F fulfilled"))
      expect(package.reload.status).to eq("arrived")
      expect(package.pending_review_count).to eq(1)

      blocker.update!(review_requested: false)

      package.reload
      expect(package.status).to eq("completed")
      expect(package.auto_completed).to be true
      expect(package.pending_review_count).to eq(0)
    end

    it "completes when the last blocking line is removed" do
      package = create_package
      fulfilled = build_item(package, review_requested: true)
      fulfilled.save!
      removable = build_item(package, review_requested: true)
      removable.save!

      fulfilled.update!(review: published_review("Phase F kept"))
      expect(package.reload.status).to eq("arrived")

      removable.destroy

      package.reload
      expect(package.status).to eq("completed")
      expect(package.auto_completed).to be true
    end

    it "reopens an auto-completed package when its review is unpublished" do
      package = create_package
      review = published_review("Phase F unpublish again")
      build_item(package, review_requested: true, review: review).save!
      expect(package.reload.status).to eq("completed")

      review.update!(status: "draft")

      package.reload
      expect(package.status).to eq("reviewing")
      expect(package.auto_completed).to be false
    end

    it "never reopens a package that a reviewer completed deliberately" do
      package = create_package
      item = build_item(package, review_requested: true)
      item.save!
      package.mark_completed!
      expect(package.reload.auto_completed).to be false

      item.update!(review: published_review("Phase F deliberate"))

      package.reload
      expect(package.status).to eq("completed")
      expect(package.auto_completed).to be false
    end

    it "leaves a package that has not arrived alone, even when a review is published" do
      package = create_package(status: "announced", arrived_at: nil, review_deadline: nil)
      build_item(package, review_requested: true,
                 review: published_review("Phase F announced")).save!

      expect(package.reload.status).to eq("announced")
    end
  end
end
