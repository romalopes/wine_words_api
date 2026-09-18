require "rails_helper"

# Unit specs for WinePackages::MarkCompleted — a reviewer's deliberate
# completion, which is never undone automatically.
RSpec.describe WinePackages::MarkCompleted do
  let(:producer) { Producer.create!(name: "Phase F Completed Producer") }
  let(:reviewer) { create_user("Phase F Completed Reviewer", "phase-f-completed@example.com") }
  let(:wine) { Wine.create!(name: "Phase F Completed Wine", producer: producer, color: "Red") }
  let(:vintage) { Vintage.create!(wine: wine, year: 2017) }
  let(:completed_at) { Time.zone.local(2026, 12, 20, 15, 0) }

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

  it "completes the package and stamps reviewed_at" do
    package = create_package

    described_class.call(package, at: completed_at)

    package.reload
    expect(package.status).to eq("completed")
    expect(package.reviewed_at).to be_within(1.second).of(completed_at)
  end

  it "returns the package" do
    package = create_package

    expect(described_class.call(package)).to eq(package)
  end

  it "records the completion as deliberate, so it can never be reopened automatically" do
    package = create_package
    package.update!(auto_completed: true) # as if it had completed itself earlier

    described_class.call(package)

    expect(package.reload.auto_completed).to be false
  end

  it "completes even when reviews are still outstanding" do
    package = create_package
    package.wine_package_items.create!(vintage: vintage, review_requested: true)

    described_class.call(package)

    package.reload
    expect(package.status).to eq("completed")
    expect(package.pending_review_count).to eq(1)
  end

  it "does not move reviewed_at on a repeated call" do
    package = create_package
    described_class.call(package, at: completed_at)

    described_class.call(package, at: completed_at + 2.days)

    expect(package.reload.reviewed_at).to be_within(1.second).of(completed_at)
  end

  it "refuses a package that has not arrived" do
    package = create_package(status: "draft", arrived_at: nil, review_deadline: nil)

    expect { described_class.call(package) }
      .to raise_error(WinePackage::InvalidTransition)
  end

  it "refuses a cancelled package" do
    package = create_package(status: "cancelled")

    expect { described_class.call(package) }
      .to raise_error(WinePackage::InvalidTransition)
  end
end
