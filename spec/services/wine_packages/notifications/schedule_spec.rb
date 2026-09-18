require "rails_helper"

# Unit specs for WinePackages::Notifications::Schedule — the 15/5/0-day
# review-deadline reminders.
#
# It only creates rows (delivery belongs to the recurring job), and it must be
# idempotent because it is called on every arrival and completion as well as
# daily by the scheduler.
RSpec.describe WinePackages::Notifications::Schedule do
  let(:producer) { Producer.create!(name: "Phase F Schedule Producer") }
  let(:reviewer) { create_user("Phase F Schedule Reviewer", "phase-f-schedule@example.com") }
  let(:creator) { create_user("Phase F Schedule Creator", "phase-f-schedule-creator@example.com") }
  let(:today) { Date.current }
  let(:deadline) { today + 30 }

  def create_user(name, email)
    User.create!(user_name: name, email: email, password: "password123")
  end

  def create_package(attrs = {})
    WinePackage.create!(
      {
        producer: producer, reviewer: reviewer, created_by: creator,
        source: "unexpected", status: "arrived",
        arrived_at: Time.current, review_deadline: deadline
      }.merge(attrs)
    )
  end

  it "creates one reminder on each threshold day before the deadline" do
    package = create_package

    reminders = described_class.call(package, at: today)

    expect(reminders.size).to eq(3)
    expect(reminders.map(&:scheduled_date).sort)
      .to eq([ deadline - 15, deadline - 5, deadline ])
    expect(reminders.map(&:notification_type).uniq).to eq([ "wine_package_deadline" ])
    expect(reminders.map(&:recipient).uniq).to eq([ reviewer ])
    expect(reminders.map(&:sent_at).uniq).to eq([ nil ])
    expect(reminders.map(&:notifiable).uniq).to eq([ package ])
  end

  it "returns whatever already existed" do
    package = create_package
    described_class.call(package, at: today)

    reminders = described_class.call(package, at: today)

    expect(reminders.size).to eq(3)
    expect(Notification.where(wine_package: package).count).to eq(3)
  end

  it "words each reminder around the day it goes out" do
    package = create_package
    package.wine_package_items.create!(review_requested: true)

    described_class.call(package, at: today)

    first = Notification.find_by!(wine_package: package, scheduled_date: deadline - 15)
    last = Notification.find_by!(wine_package: package, scheduled_date: deadline)

    expect(first.message).to include("Phase F Schedule Producer")
    expect(first.message).to include("1 review(s) still pending")
    expect(first.message).to include("in 15 days")
    expect(last.message).to include("is today")
    expect(last.message).to include(deadline.to_s)
  end

  it "skips the reminders whose day has already passed" do
    package = create_package(review_deadline: today + 10)

    reminders = described_class.call(package, at: today)

    expect(reminders.map(&:scheduled_date).sort).to eq([ today + 5, today + 10 ])
  end

  it "does nothing for a package without a deadline" do
    package = create_package(status: "announced", arrived_at: nil, review_deadline: nil)

    expect(described_class.call(package, at: today)).to eq([])
    expect(Notification.where(wine_package: package).count).to eq(0)
  end

  it "does nothing for a package that is already finished" do
    %w[completed cancelled].each do |status|
      package = create_package(status: status)
      expect(described_class.call(package, at: today)).to eq([]),
        "#{status} packages should not be reminded"
    end

    rejected = create_package(status: "rejected", rejection_reason: "No capacity")
    expect(described_class.call(rejected, at: today)).to eq([])
  end

  it "does nothing for an unsaved package" do
    package = WinePackage.new(producer: producer, reviewer: reviewer,
                              source: "unexpected", review_deadline: deadline)

    expect(described_class.call(package, at: today)).to eq([])
  end

  it "falls back to whoever recorded the package" do
    package = create_package(reviewer: nil)

    reminders = described_class.call(package, at: today)

    expect(reminders.map(&:recipient).uniq).to eq([ creator ])
  end

  it "does nothing when nobody can be notified" do
    package = create_package(reviewer: nil, created_by: nil)

    expect(described_class.call(package, at: today)).to eq([])
    expect(Notification.where(wine_package: package).count).to eq(0)
  end

  it "is idempotent across repeated scheduling passes" do
    package = create_package

    3.times { described_class.call(package, at: today) }

    expect(Notification.where(wine_package: package).count).to eq(3)
  end
end
