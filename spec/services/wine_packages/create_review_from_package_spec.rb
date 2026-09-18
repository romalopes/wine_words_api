require "rails_helper"

# Unit specs for WinePackages::CreateReviewFromPackage — starts the ordinary
# review flow from a package line and links the two together.
RSpec.describe WinePackages::CreateReviewFromPackage do
  let(:producer) { Producer.create!(name: "Phase F Review Producer") }
  let(:reviewer) { create_user("Phase F Review Reviewer", "phase-f-review@example.com") }
  let(:wine) { Wine.create!(name: "Phase F Review Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2016) }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  def create_package(attrs = {})
    WinePackage.create!(
      {
        producer: producer, reviewer: reviewer, created_by: reviewer,
        source: "unexpected", status: "arrived",
        arrived_at: Time.current, review_deadline: Date.current + 30
      }.merge(attrs)
    )
  end

  def requested_item(package, attrs = {})
    package.wine_package_items.create!({ vintage: vintage, review_requested: true }.merge(attrs))
  end

  describe ".call" do
    it "creates a draft review through the ordinary review path and links it" do
      package = create_package
      item = requested_item(package)

      review = described_class.call(item, user: reviewer,
                                          attributes: { title: "Phase F from package", score: 91 })

      expect(review).to be_persisted
      expect(review.status).to eq("draft")
      expect(review.vintage).to eq(vintage)
      expect(review.user).to eq(reviewer)
      expect(review.title).to eq("Phase F from package")
      expect(item.reload.review).to eq(review)
      expect(review.slug).to be_present
    end

    it "leaves the package open while the review is a draft" do
      package = create_package
      item = requested_item(package)

      described_class.call(item, user: reviewer, attributes: { title: "Phase F draft", score: 90 })

      package.reload
      expect(package.status).to eq("arrived")
      expect(package.pending_review_count).to eq(1)
    end

    it "completes the package when the review is created published" do
      package = create_package
      item = requested_item(package)

      described_class.call(item, user: reviewer,
                                 attributes: { title: "Phase F published", score: 93,
                                               status: "published" })

      package.reload
      expect(package.status).to eq("completed")
      expect(package.auto_completed).to be true
      expect(package.review_progress).to eq(requested: 1, reviewed: 1, pending: 0, percent: 100)
    end

    it "applies the normal review validations" do
      package = create_package
      item = requested_item(package)

      expect do
        described_class.call(item, user: reviewer, attributes: { title: "No score" })
      end.to raise_error(ActiveRecord::RecordInvalid)
      expect(item.reload.review_id).to be_nil
    end

    it "refuses a line that was not requested for review" do
      package = create_package
      item = requested_item(package, review_requested: false)

      expect { described_class.call(item, user: reviewer) }
        .to raise_error(WinePackages::Error, /not marked for review/)
      expect(Review.count).to eq(0)
    end

    it "refuses a line that already has a review" do
      package = create_package
      item = requested_item(package)
      described_class.call(item, user: reviewer, attributes: { title: "First", score: 90 })

      expect { described_class.call(item, user: reviewer) }
        .to raise_error(WinePackages::Error, /already has a review/)
    end

    it "refuses a line with no wine in the catalogue" do
      package = create_package
      unmatched = package.wine_package_items.create!(review_requested: true)

      expect { described_class.call(unmatched, user: reviewer) }
        .to raise_error(WinePackages::Error, /not linked to a wine/)
    end

    it "refuses to create an orphan review" do
      package = create_package
      item = requested_item(package)

      expect { described_class.call(item, user: nil) }
        .to raise_error(WinePackages::Error, /needs a reviewer/)
      expect(Review.count).to eq(0)
    end
  end
end
