require "rails_helper"

# Unit specs for WinePackages::CheckCompletion — the single source of truth for
# automatic completion.
#
# The rules it encodes: only review_requested lines block, a package must have
# arrived before it can complete itself, and a deliberate completion is never
# undone. (The hooks that call it are covered by the wine_package_item specs.)
RSpec.describe WinePackages::CheckCompletion do
  let(:producer) { Producer.create!(name: "Phase F Service Producer") }
  let(:reviewer) { create_user("Phase F Service Reviewer", "phase-f-service@example.com") }
  let(:wine) { Wine.create!(name: "Phase F Service Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2018) }

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

  def add_item(package, requested:, review: nil)
    package.wine_package_items.create!(vintage: vintage, review_requested: requested,
                                       review: review)
  end

  def published_review(title)
    Review.create!(vintage: vintage, user: reviewer, title: title, score: 90,
                   status: "published")
  end

  it "returns the package it was given" do
    package = create_package
    add_item(package, requested: true, review: published_review("Phase F returns"))

    expect(described_class.call(package)).to eq(package)
  end

  it "tolerates a nil or unsaved package" do
    expect(described_class.call(nil)).to be_nil

    unsaved = WinePackage.new(producer: producer)
    expect(described_class.call(unsaved)).to eq(unsaved)
    expect(unsaved).not_to be_persisted
  end

  it "completes an arrived package whose requested lines are all published" do
    package = create_package
    add_item(package, requested: true, review: published_review("Phase F completes"))

    described_class.call(package)

    package.reload
    expect(package.status).to eq("completed")
    expect(package.auto_completed).to be true
    expect(package.reviewed_at).to be_present
  end

  it "completes a package that is already being reviewed" do
    package = create_package(status: "reviewing")
    add_item(package, requested: true, review: published_review("Phase F reviewing"))

    described_class.call(package)

    expect(package.reload.status).to eq("completed")
  end

  it "does not complete while a requested line is still pending" do
    package = create_package
    fulfilled = add_item(package, requested: true)
    add_item(package, requested: true)

    # Fulfilling one of two lines leaves the other outstanding.
    fulfilled.update!(review: published_review("Phase F done line"))
    expect(package.reload.status).to eq("arrived")

    described_class.call(package)

    package.reload
    expect(package.status).to eq("arrived")
    expect(package.auto_completed).to be false
    expect(package.pending_review_count).to eq(1)
  end

  it "never completes a package with nothing requested for review" do
    package = create_package
    add_item(package, requested: false, review: published_review("Phase F not requested"))

    described_class.call(package)

    expect(package.reload.status).to eq("arrived")
  end

  it "never completes a package that has not arrived" do
    package = create_package(status: "announced", arrived_at: nil, review_deadline: nil)
    add_item(package, requested: true, review: published_review("Phase F announced"))

    described_class.call(package)

    expect(package.reload.status).to eq("announced")
  end

  it "leaves cancelled and rejected packages alone" do
    cancelled = create_package(status: "cancelled")
    add_item(cancelled, requested: true, review: published_review("Phase F cancelled"))
    rejected = create_package(status: "rejected", rejection_reason: "No capacity")
    add_item(rejected, requested: true, review: published_review("Phase F rejected"))

    described_class.call(cancelled)
    described_class.call(rejected)

    expect(cancelled.reload.status).to eq("cancelled")
    expect(rejected.reload.status).to eq("rejected")
  end

  it "reopens an auto-completed package when work reappears" do
    package = create_package
    add_item(package, requested: true, review: published_review("Phase F reopen me"))
    described_class.call(package)
    expect(package.reload.status).to eq("completed")

    add_item(package, requested: true)
    described_class.call(package)

    package.reload
    expect(package.status).to eq("reviewing")
    expect(package.auto_completed).to be false
  end

  it "never reopens a completion a reviewer made deliberately" do
    package = create_package
    add_item(package, requested: true)
    package.mark_completed!          # deliberate: auto_completed stays false
    add_item(package, requested: true, review: nil)

    described_class.call(package)

    package.reload
    expect(package.status).to eq("completed")
    expect(package.auto_completed).to be false
  end

  it "is idempotent" do
    package = create_package
    add_item(package, requested: true, review: published_review("Phase F twice"))

    3.times { described_class.call(package) }

    package.reload
    expect(package.status).to eq("completed")
    expect(package.auto_completed).to be true
  end
end
